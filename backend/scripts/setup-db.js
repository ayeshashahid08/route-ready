require('dotenv').config();
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');

async function main() {
  // A separate connection (not the app pool) because it must allow several
  // statements in one go. The app itself never needs that, and leaving it off
  // there is safer.
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    multipleStatements: true,
  });

  if (process.argv.includes('--reset')) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('Refusing to reset in production');
    }
    const [tables] = await conn.query(
      'SELECT table_name AS name FROM information_schema.tables WHERE table_schema = ?',
      [process.env.DB_NAME]
    );
    await conn.query('SET FOREIGN_KEY_CHECKS = 0');
    for (const t of tables) {
      await conn.query(`DROP TABLE IF EXISTS \`${t.name}\``);
    }
    await conn.query('SET FOREIGN_KEY_CHECKS = 1');
    console.log(`Dropped ${tables.length} tables`);
  }

  const dir = path.join(__dirname, '..', 'sql');
  const files = fs.readdirSync(dir).filter((f) => f.endsWith('.sql')).sort();
  for (const file of files) {
    await conn.query(fs.readFileSync(path.join(dir, file), 'utf8'));
    console.log('Applied', file);
  }

  await conn.end();
}

main().catch((err) => {
  console.error('Setup failed:', err.message);
  process.exit(1);
});