require('dotenv').config();
const app = require('./app');
const pool = require('./db');

async function start() {
  await pool.query('SELECT 1'); // fail fast if MySQL is unreachable
  console.log('MySQL connected');
  const port = process.env.PORT || 3000;
  app.listen(port, () => console.log(`API running on port ${port}`));
}

start().catch((err) => {
  console.error('Startup failed:', err.message);
  process.exit(1);
});