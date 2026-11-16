-- Reference data. Times are ASSUMPTIONS from your notes: confirm with the head.
INSERT IGNORE INTO shifts (shift_code, direction, campus_time) VALUES
  ('A', 'pickup',  '08:00:00'),
  ('B', 'pickup',  '10:00:00'),
  ('C', 'pickup',  '11:00:00'),
  ('D', 'pickup',  '14:00:00'),
  ('Y', 'dropoff', '15:30:00'),
  ('Z', 'dropoff', '18:30:00');

-- A, B, C, Y, Z run Monday to Friday. D runs Tuesday and Thursday only.
INSERT IGNORE INTO shift_days (shift_code, weekday) VALUES
  ('A',1),('A',2),('A',3),('A',4),('A',5),
  ('B',1),('B',2),('B',3),('B',4),('B',5),
  ('C',1),('C',2),('C',3),('C',4),('C',5),
  ('D',2),('D',4),
  ('Y',1),('Y',2),('Y',3),('Y',4),('Y',5),
  ('Z',1),('Z',2),('Z',3),('Z',4),('Z',5);
