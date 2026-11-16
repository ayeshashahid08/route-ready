-- RouteReady schema (MySQL 8.0.16+). Tables are in dependency order:
-- a foreign key can only point at a table that already exists.

-- ---------- People ----------

CREATE TABLE IF NOT EXISTS users (
  user_id INT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(100) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  email VARCHAR(150) NULL,
  password_hash VARCHAR(255) NOT NULL,
  must_change_password BOOLEAN NOT NULL DEFAULT TRUE,
  home_lat DECIMAL(9,6) NULL,
  home_lng DECIMAL(9,6) NULL,
  maps_url VARCHAR(500) NULL,
  address_note VARCHAR(255) NULL,
  location_updated_at TIMESTAMP NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_users_phone UNIQUE (phone),
  CONSTRAINT uq_users_email UNIQUE (email),
  CONSTRAINT ck_users_lat CHECK (home_lat IS NULL OR home_lat BETWEEN -90 AND 90),
  CONSTRAINT ck_users_lng CHECK (home_lng IS NULL OR home_lng BETWEEN -180 AND 180),
  CONSTRAINT ck_users_latlng_pair CHECK ((home_lat IS NULL) = (home_lng IS NULL))
);

CREATE TABLE IF NOT EXISTS user_roles (
  user_id INT NOT NULL,
  role VARCHAR(10) NOT NULL,
  PRIMARY KEY (user_id, role),
  CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id) REFERENCES users (user_id),
  CONSTRAINT ck_user_roles_role CHECK (role IN ('head', 'captain', 'student'))
);

CREATE TABLE IF NOT EXISTS captain_documents (
  captain_id INT PRIMARY KEY,
  cnic_encrypted VARCHAR(255) NOT NULL,
  licence_no_encrypted VARCHAR(255) NOT NULL,
  licence_expiry DATE NOT NULL,
  verification_status VARCHAR(10) NOT NULL DEFAULT 'pending',
  verified_by INT NULL,
  verified_at TIMESTAMP NULL,
  rejection_reason VARCHAR(255) NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_capdocs_captain FOREIGN KEY (captain_id) REFERENCES users (user_id),
  CONSTRAINT fk_capdocs_verifier FOREIGN KEY (verified_by) REFERENCES users (user_id),
  CONSTRAINT ck_capdocs_status CHECK (verification_status IN ('pending', 'verified', 'rejected'))
);

CREATE TABLE IF NOT EXISTS licence_reminders (
  captain_id INT NOT NULL,
  licence_expiry DATE NOT NULL,
  days_before SMALLINT NOT NULL,
  sent_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (captain_id, licence_expiry, days_before),
  CONSTRAINT fk_licrem_captain FOREIGN KEY (captain_id) REFERENCES users (user_id),
  CONSTRAINT ck_licrem_days CHECK (days_before IN (45, 30, 14, 7, 1, 0))
);

CREATE TABLE IF NOT EXISTS vans (
  van_id INT AUTO_INCREMENT PRIMARY KEY,
  plate_number VARCHAR(20) NOT NULL,
  capacity SMALLINT NOT NULL DEFAULT 7,
  ownership VARCHAR(20) NOT NULL,
  captain_id INT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT uq_vans_plate UNIQUE (plate_number),
  CONSTRAINT uq_vans_captain UNIQUE (captain_id),
  CONSTRAINT fk_vans_captain FOREIGN KEY (captain_id) REFERENCES users (user_id),
  CONSTRAINT ck_vans_capacity CHECK (capacity > 0),
  CONSTRAINT ck_vans_ownership CHECK (ownership IN ('captain_owned', 'head_provided'))
);

-- ---------- Shifts and captain availability ----------

CREATE TABLE IF NOT EXISTS shifts (
  shift_code VARCHAR(5) PRIMARY KEY,
  direction VARCHAR(10) NOT NULL,
  campus_time TIME NOT NULL,
  CONSTRAINT ck_shifts_direction CHECK (direction IN ('pickup', 'dropoff'))
);

CREATE TABLE IF NOT EXISTS shift_days (
  shift_code VARCHAR(5) NOT NULL,
  weekday SMALLINT NOT NULL,
  PRIMARY KEY (shift_code, weekday),
  CONSTRAINT fk_shiftdays_shift FOREIGN KEY (shift_code) REFERENCES shifts (shift_code),
  CONSTRAINT ck_shiftdays_weekday CHECK (weekday BETWEEN 1 AND 5)
);

CREATE TABLE IF NOT EXISTS captain_unavailable_shifts (
  captain_id INT NOT NULL,
  shift_code VARCHAR(5) NOT NULL,
  PRIMARY KEY (captain_id, shift_code),
  CONSTRAINT fk_capunav_captain FOREIGN KEY (captain_id) REFERENCES users (user_id),
  CONSTRAINT fk_capunav_shift FOREIGN KEY (shift_code) REFERENCES shifts (shift_code)
);

CREATE TABLE IF NOT EXISTS captain_leaves (
  leave_id INT AUTO_INCREMENT PRIMARY KEY,
  captain_id INT NOT NULL,
  leave_date DATE NOT NULL,
  shift_code VARCHAR(5) NULL,
  reason VARCHAR(255) NULL,
  created_by INT NOT NULL,
  INDEX idx_leaves_captain_date (captain_id, leave_date),
  CONSTRAINT fk_leaves_captain FOREIGN KEY (captain_id) REFERENCES users (user_id),
  CONSTRAINT fk_leaves_shift FOREIGN KEY (shift_code) REFERENCES shifts (shift_code),
  CONSTRAINT fk_leaves_creator FOREIGN KEY (created_by) REFERENCES users (user_id)
);

-- ---------- Student schedule ----------

CREATE TABLE IF NOT EXISTS terms (
  term_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  CONSTRAINT ck_terms_dates CHECK (end_date >= start_date)
);

CREATE TABLE IF NOT EXISTS student_schedule (
  schedule_id INT AUTO_INCREMENT PRIMARY KEY,
  term_id INT NOT NULL,
  student_id INT NOT NULL,
  weekday SMALLINT NOT NULL,
  pickup_shift_code VARCHAR(5) NULL,
  dropoff_shift_code VARCHAR(5) NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by INT NOT NULL,
  CONSTRAINT uq_schedule_term_student_day UNIQUE (term_id, student_id, weekday),
  CONSTRAINT fk_schedule_term FOREIGN KEY (term_id) REFERENCES terms (term_id),
  CONSTRAINT fk_schedule_student FOREIGN KEY (student_id) REFERENCES users (user_id),
  CONSTRAINT fk_schedule_pickup FOREIGN KEY (pickup_shift_code) REFERENCES shifts (shift_code),
  CONSTRAINT fk_schedule_dropoff FOREIGN KEY (dropoff_shift_code) REFERENCES shifts (shift_code),
  CONSTRAINT fk_schedule_updater FOREIGN KEY (updated_by) REFERENCES users (user_id),
  CONSTRAINT ck_schedule_weekday CHECK (weekday BETWEEN 1 AND 5),
  CONSTRAINT ck_schedule_one_shift CHECK (pickup_shift_code IS NOT NULL OR dropoff_shift_code IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS ride_exceptions (
  exception_id INT AUTO_INCREMENT PRIMARY KEY,
  student_id INT NOT NULL,
  ride_date DATE NOT NULL,
  direction VARCHAR(10) NOT NULL,
  exception_type VARCHAR(20) NOT NULL,
  new_shift_code VARCHAR(5) NULL,
  status VARCHAR(15) NOT NULL DEFAULT 'applied',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  decided_by INT NULL,
  CONSTRAINT uq_exceptions_student_date_dir UNIQUE (student_id, ride_date, direction),
  CONSTRAINT fk_exceptions_student FOREIGN KEY (student_id) REFERENCES users (user_id),
  CONSTRAINT fk_exceptions_shift FOREIGN KEY (new_shift_code) REFERENCES shifts (shift_code),
  CONSTRAINT fk_exceptions_decider FOREIGN KEY (decided_by) REFERENCES users (user_id),
  CONSTRAINT ck_exceptions_direction CHECK (direction IN ('pickup', 'dropoff')),
  CONSTRAINT ck_exceptions_type CHECK (exception_type IN ('cancel', 'change_shift', 'add')),
  CONSTRAINT ck_exceptions_status CHECK (status IN ('applied', 'pending_head', 'rejected')),
  CONSTRAINT ck_exceptions_shift_rule CHECK (
    (exception_type = 'cancel' AND new_shift_code IS NULL)
    OR (exception_type <> 'cancel' AND new_shift_code IS NOT NULL)
  )
);

-- ---------- Generated plans ----------

CREATE TABLE IF NOT EXISTS plans (
  plan_id INT AUTO_INCREMENT PRIMARY KEY,
  plan_date DATE NOT NULL,
  shift_code VARCHAR(5) NOT NULL,
  status VARCHAR(15) NOT NULL DEFAULT 'draft',
  generated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  published_at TIMESTAMP NULL,
  published_by INT NULL,
  CONSTRAINT uq_plans_date_shift UNIQUE (plan_date, shift_code),
  CONSTRAINT fk_plans_shift FOREIGN KEY (shift_code) REFERENCES shifts (shift_code),
  CONSTRAINT fk_plans_publisher FOREIGN KEY (published_by) REFERENCES users (user_id),
  CONSTRAINT ck_plans_status CHECK (status IN ('draft', 'published')),
  CONSTRAINT ck_plans_published CHECK (
    (status = 'published' AND published_at IS NOT NULL AND published_by IS NOT NULL)
    OR (status = 'draft' AND published_at IS NULL AND published_by IS NULL)
  )
);

CREATE TABLE IF NOT EXISTS trips (
  trip_id INT AUTO_INCREMENT PRIMARY KEY,
  plan_id INT NOT NULL,
  captain_id INT NOT NULL,
  start_time TIME NOT NULL,
  status VARCHAR(15) NOT NULL DEFAULT 'planned',
  CONSTRAINT uq_trips_plan_captain UNIQUE (plan_id, captain_id),
  CONSTRAINT uq_trips_trip_plan UNIQUE (trip_id, plan_id),
  CONSTRAINT fk_trips_plan FOREIGN KEY (plan_id) REFERENCES plans (plan_id),
  CONSTRAINT fk_trips_captain FOREIGN KEY (captain_id) REFERENCES users (user_id),
  CONSTRAINT ck_trips_status CHECK (status IN ('planned', 'in_progress', 'completed'))
);

CREATE TABLE IF NOT EXISTS trip_stops (
  stop_id INT AUTO_INCREMENT PRIMARY KEY,
  trip_id INT NOT NULL,
  plan_id INT NOT NULL,
  student_id INT NOT NULL,
  stop_order SMALLINT NOT NULL,
  planned_time TIME NOT NULL,
  status VARCHAR(15) NOT NULL DEFAULT 'pending',
  status_updated_at TIMESTAMP NULL,
  CONSTRAINT uq_stops_trip_order UNIQUE (trip_id, stop_order),
  CONSTRAINT uq_stops_plan_student UNIQUE (plan_id, student_id),
  CONSTRAINT fk_stops_trip_plan FOREIGN KEY (trip_id, plan_id) REFERENCES trips (trip_id, plan_id),
  CONSTRAINT fk_stops_student FOREIGN KEY (student_id) REFERENCES users (user_id),
  CONSTRAINT ck_stops_status CHECK (status IN ('pending', 'picked_up', 'no_show', 'cancelled'))
);

-- ---------- Inbox, audit, settings ----------

CREATE TABLE IF NOT EXISTS notifications (
  notification_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  plan_id INT NULL,
  message VARCHAR(255) NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_notif_user_read (user_id, is_read),
  CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users (user_id),
  CONSTRAINT fk_notif_plan FOREIGN KEY (plan_id) REFERENCES plans (plan_id)
);

CREATE TABLE IF NOT EXISTS audit_log (
  log_id INT AUTO_INCREMENT PRIMARY KEY,
  actor_id INT NOT NULL,
  action VARCHAR(50) NOT NULL,
  entity_type VARCHAR(50) NOT NULL,
  entity_id VARCHAR(30) NULL,
  details JSON NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_audit_actor FOREIGN KEY (actor_id) REFERENCES users (user_id)
);

CREATE TABLE IF NOT EXISTS app_settings (
  setting_key VARCHAR(50) PRIMARY KEY,
  setting_value VARCHAR(100) NOT NULL,
  updated_by INT NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_settings_updater FOREIGN KEY (updated_by) REFERENCES users (user_id)
);
