require('dotenv').config();
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');

const DEV_PASSWORD = 'Dev12345'; // fake, local dev only
const CAMPUS = { lat: 31.5, lng: 74.3 }; // arbitrary point, not a real campus
const pad = (n) => String(n).padStart(4, '0');

// Deterministic scatter within about 5 km of the campus point.
function homeFor(seed) {
  const dLat = (((seed * 37) % 100) - 50) / 1000;
  const dLng = (((seed * 53) % 100) - 50) / 1000;
  return [(CAMPUS.lat + dLat).toFixed(6), (CAMPUS.lng + dLng).toFixed(6)];
}

const staff = [
  { name: 'Hamid Head', roles: ['head', 'captain'], plate: 'FAKE-001', own: 'captain_owned', status: 'verified', expiryDays: 300 },
  { name: 'Imran Captain', roles: ['captain'], plate: 'FAKE-002', own: 'captain_owned', status: 'verified', expiryDays: 200 },
  { name: 'Bilal Captain', roles: ['captain'], plate: 'FAKE-003', own: 'head_provided', status: 'verified', expiryDays: 40 },
  { name: 'Salman PartTime', roles: ['captain'], plate: 'FAKE-004', own: 'captain_owned', status: 'verified', expiryDays: 150, unavailable: ['A', 'B', 'C', 'D'] },
  { name: 'Tariq Expired', roles: ['captain'], plate: 'FAKE-005', own: 'head_provided', status: 'verified', expiryDays: -10 },
  { name: 'Danish Pending', roles: ['captain'], plate: 'FAKE-006', own: 'captain_owned', status: 'pending', expiryDays: 100 },
];

// [pickup shift, dropoff shift] for student i on weekday (1=Mon ... 5=Fri)
function shiftsFor(i, day) {
  if (i <= 9) return ['A', 'Y'];
  if (i <= 14) return [i === 14 && (day === 2 || day === 4) ? 'D' : 'B', 'Z'];
  if (i === 15) return ['C', 'Y'];
  return ['A', null]; // student 16: pickup only
}

async function addUser(conn, u) {
  const [r] = await conn.query(
    `INSERT INTO users (full_name, phone, password_hash, must_change_password, home_lat, home_lng, location_updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [u.name, u.phone, u.hash, u.mustChange, u.lat, u.lng, u.lat === null ? null : new Date()]
  );
  return r.insertId;
}

async function main() {
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
  });

  try {
    const [[{ n }]] = await conn.query('SELECT COUNT(*) AS n FROM users');
    if (n > 0) {
      console.log('Users already exist, nothing done. Use "npm run db:fresh" to rebuild from scratch.');
      return;
    }

    const hash = await bcrypt.hash(DEV_PASSWORD, 10);
    await conn.beginTransaction();

    let headId = null;
    for (let i = 0; i < staff.length; i++) {
      const s = staff[i];
      const [lat, lng] = homeFor(101 + i);
      const id = await addUser(conn, { name: s.name, phone: `+92300000${pad(i + 1)}`, hash, lat, lng, mustChange: false });
      if (i === 0) headId = id;

      for (const role of s.roles) {
        await conn.query('INSERT INTO user_roles (user_id, role) VALUES (?, ?)', [id, role]);
      }

      const verified = s.status === 'verified';
      await conn.query(
        `INSERT INTO captain_documents
           (captain_id, cnic_encrypted, licence_no_encrypted, licence_expiry, verification_status, verified_by, verified_at)
         VALUES (?, ?, ?, DATE_ADD(CURDATE(), INTERVAL ? DAY), ?, ?, ?)`,
        [id, `FAKE-CNIC-${i + 1}`, `FAKE-LIC-${i + 1}`, s.expiryDays, s.status, verified ? headId : null, verified ? new Date() : null]
      );

      await conn.query(
        'INSERT INTO vans (plate_number, capacity, ownership, captain_id) VALUES (?, 7, ?, ?)',
        [s.plate, s.own, id]
      );

      for (const shift of s.unavailable || []) {
        await conn.query('INSERT INTO captain_unavailable_shifts (captain_id, shift_code) VALUES (?, ?)', [id, shift]);
      }

      if (s.name.startsWith('Bilal')) {
        await conn.query(
          `INSERT INTO captain_leaves (captain_id, leave_date, shift_code, reason, created_by)
           VALUES (?, DATE_ADD(CURDATE(), INTERVAL 1 DAY), NULL, 'Fake: family event', ?)`,
          [id, headId]
        );
      }
    }

    const [term] = await conn.query(
      "INSERT INTO terms (name, start_date, end_date) VALUES ('Fall 2026', '2026-09-01', '2026-12-31')"
    );

    for (let i = 1; i <= 16; i++) {
      const noLocation = i === 16;
      const [lat, lng] = noLocation ? [null, null] : homeFor(i);
      const id = await addUser(conn, {
        name: `Student ${String(i).padStart(2, '0')}`,
        phone: `+92311000${pad(i)}`,
        hash, lat, lng,
        mustChange: noLocation,
      });
      await conn.query('INSERT INTO user_roles (user_id, role) VALUES (?, ?)', [id, 'student']);
      for (let day = 1; day <= 5; day++) {
        const [pickup, dropoff] = shiftsFor(i, day);
        await conn.query(
          `INSERT INTO student_schedule (term_id, student_id, weekday, pickup_shift_code, dropoff_shift_code, updated_by)
           VALUES (?, ?, ?, ?, ?, ?)`,
          [term.insertId, id, day, pickup, dropoff, headId]
        );
      }
    }

    await conn.query(
      `INSERT INTO app_settings (setting_key, setting_value, updated_by) VALUES
         ('campus_lat', ?, ?), ('campus_lng', ?, ?)`,
      [String(CAMPUS.lat), headId, String(CAMPUS.lng), headId]
    );

    await conn.commit();
    console.log('Seeded: 6 staff (with vans), 16 students, 1 term, schedules, 1 leave, campus location.');
    console.log(`Login with any phone, e.g. +9230000${pad(1)} (head), password: ${DEV_PASSWORD}`);
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    await conn.end();
  }
}

main().catch((err) => {
  console.error('Seed failed:', err.message);
  process.exit(1);
});
