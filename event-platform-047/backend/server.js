require('dotenv').config();
const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const { pool, initDB } = require('./db');
const authRouter = require('./auth');
const { connectRabbitMQ, publishMessage } = require('./rabbitmq');

const app = express();
app.use(cors());
app.use(express.json());

function authMiddleware(req, res, next) {
  const auth = req.headers['authorization'];
  if (!auth || !auth.startsWith('Bearer '))
    return res.status(401).json({ error: 'No token provided' });
  const token = auth.split(' ')[1];
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ error: 'Invalid or expired token' });
  }
}

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'backend_047', timestamp: new Date().toISOString() });
});

app.use('/auth', authRouter);

app.post('/events/create', authMiddleware, async (req, res) => {
  const { title, description, region } = req.body;
  if (!title || !region)
    return res.status(400).json({ error: 'title and region required' });
  try {
    const result = await pool.query(
      'INSERT INTO events (title, description, region, created_by) VALUES ($1, $2, $3, $4) RETURNING *',
      [title, description || '', region, req.user.id]
    );
    const event = result.rows[0];

    await pool.query(
      'INSERT INTO event_logs (event_id, action, message) VALUES ($1, $2, $3)',
      [
        event.id,
        'event_created',
        'Event "' + title + '" created in region "' + region + '" by user ' + req.user.id
      ]
    );

    await publishMessage(
      process.env.QUEUE_NAME,
      JSON.stringify({ title, region, event_id: event.id, created_by: req.user.id })
    );

    res.status(201).json({ message: 'Event created', event });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/events', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT e.*, u.name as creator_name FROM events e LEFT JOIN users u ON e.created_by = u.id ORDER BY e.created_at DESC'
    );
    res.json({ count: result.rows.length, events: result.rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/logs', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM event_logs ORDER BY created_at DESC');
    res.json({ count: result.rows.length, logs: result.rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

async function start() {
  await initDB();
  await connectRabbitMQ();
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => console.log('backend_047 running on port ' + PORT));
}

start().catch(err => {
  console.error('Fatal startup error:', err.message);
  process.exit(1);
});
