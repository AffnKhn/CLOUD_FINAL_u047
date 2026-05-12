#!/bin/bash
# CE408L Cloud Computing Lab - Final Exam
# Event Platform Setup Script
# IMPORTANT: Replace 047 with your actual last 3 roll digits before running
# Usage: bash setup.sh

set -e

ROLL="047"
PROJECT="event-platform-${ROLL}"

echo "============================================"
echo " CE408L Event Platform Setup - Roll: $ROLL"
echo "============================================"

# ── STEP 1: Install Docker ────────────────────────────────────────────────────
echo ""
echo "[1/6] Checking Docker..."
if ! command -v docker &> /dev/null; then
  echo "Installing Docker..."
  sudo apt update -y
  sudo apt install -y docker.io
  sudo systemctl start docker
  sudo systemctl enable docker
  sudo usermod -aG docker $USER
  echo "Docker installed. NOTE: Log out and back in if 'permission denied' errors occur."
else
  echo "Docker already installed: $(docker --version)"
fi

# ── STEP 2: Install Docker Compose plugin ────────────────────────────────────
echo ""
echo "[2/6] Checking Docker Compose..."
if ! docker compose version &> /dev/null; then
  echo "Installing Docker Compose plugin..."
  sudo apt install -y docker-compose-plugin
else
  echo "Docker Compose already installed: $(docker compose version)"
fi

# ── STEP 3: Create project structure ─────────────────────────────────────────
echo ""
echo "[3/6] Creating project structure: $PROJECT"
mkdir -p ${PROJECT}/backend
mkdir -p ${PROJECT}/consumer
cd ${PROJECT}

# ── STEP 4: Write all files ───────────────────────────────────────────────────
echo ""
echo "[4/6] Writing all project files..."

# ── docker-compose.yml ────────────────────────────────────────────────────────
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  postgres_${ROLL}:
    image: postgres:15
    container_name: postgres_${ROLL}
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres123
      POSTGRES_DB: eventdb_${ROLL}
    volumes:
      - postgres_data_${ROLL}:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - event_net_${ROLL}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  rabbitmq_${ROLL}:
    image: rabbitmq:3-management
    container_name: rabbitmq_${ROLL}
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
    ports:
      - "5672:5672"
      - "15672:15672"
    networks:
      - event_net_${ROLL}
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "ping"]
      interval: 15s
      timeout: 10s
      retries: 10

  backend_${ROLL}:
    build: ./backend
    container_name: backend_${ROLL}
    env_file: ./backend/.env
    ports:
      - "3000:3000"
    depends_on:
      postgres_${ROLL}:
        condition: service_healthy
      rabbitmq_${ROLL}:
        condition: service_healthy
    networks:
      - event_net_${ROLL}
    restart: on-failure

  consumer_${ROLL}:
    build: ./consumer
    container_name: consumer_${ROLL}
    env_file: ./consumer/.env
    depends_on:
      rabbitmq_${ROLL}:
        condition: service_healthy
    networks:
      - event_net_${ROLL}
    restart: on-failure

networks:
  event_net_${ROLL}:
    driver: bridge

volumes:
  postgres_data_${ROLL}:
EOF

echo "  [ok] docker-compose.yml"

# ── backend/.env ──────────────────────────────────────────────────────────────
cat > backend/.env <<EOF
PORT=3000
DB_HOST=postgres_${ROLL}
DB_PORT=5432
DB_NAME=eventdb_${ROLL}
DB_USER=postgres
DB_PASSWORD=postgres123
JWT_SECRET=jwt_secret_${ROLL}
RABBITMQ_URL=amqp://guest:guest@rabbitmq_${ROLL}:5672
QUEUE_NAME=event_created_${ROLL}
EOF

echo "  [ok] backend/.env"

# ── backend/package.json ──────────────────────────────────────────────────────
cat > backend/package.json <<'EOF'
{
  "name": "backend",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "amqplib": "^0.10.3",
    "bcryptjs": "^2.4.3",
    "cors": "^2.8.5",
    "dotenv": "^16.0.3",
    "express": "^4.18.2",
    "jsonwebtoken": "^9.0.0",
    "pg": "^8.11.0"
  }
}
EOF

echo "  [ok] backend/package.json"

# ── backend/Dockerfile ────────────────────────────────────────────────────────
cat > backend/Dockerfile <<'EOF'
FROM node:18-alpine
WORKDIR /app
COPY package.json .
RUN npm install
COPY . .
CMD ["node", "server.js"]
EOF

echo "  [ok] backend/Dockerfile"

# ── backend/db.js ─────────────────────────────────────────────────────────────
cat > backend/db.js <<'EOF'
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

async function initDB() {
  let retries = 10;
  while (retries > 0) {
    try {
      await pool.query('SELECT 1');
      break;
    } catch (err) {
      console.log('DB not ready, retrying in 3s... (' + retries + ' left)');
      retries--;
      await new Promise(r => setTimeout(r, 3000));
    }
  }

  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      name VARCHAR(255),
      email VARCHAR(255) UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS events (
      id SERIAL PRIMARY KEY,
      title VARCHAR(255),
      description TEXT,
      region VARCHAR(100),
      created_by INTEGER REFERENCES users(id),
      created_at TIMESTAMP DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS event_logs (
      id SERIAL PRIMARY KEY,
      event_id INTEGER,
      action VARCHAR(100),
      message TEXT,
      created_at TIMESTAMP DEFAULT NOW()
    )
  `);

  console.log('DB tables initialized');
}

module.exports = { pool, initDB };
EOF

echo "  [ok] backend/db.js"

# ── backend/rabbitmq.js ───────────────────────────────────────────────────────
cat > backend/rabbitmq.js <<'EOF'
const amqp = require('amqplib');

let channel;

async function connectRabbitMQ() {
  let retries = 15;
  while (retries > 0) {
    try {
      const connection = await amqp.connect(process.env.RABBITMQ_URL);
      channel = await connection.createChannel();
      await channel.assertQueue(process.env.QUEUE_NAME, { durable: true });
      console.log('RabbitMQ connected. Queue: ' + process.env.QUEUE_NAME);
      return;
    } catch (err) {
      console.log('RabbitMQ not ready, retrying... (' + retries + ' left)');
      retries--;
      await new Promise(r => setTimeout(r, 5000));
    }
  }
  throw new Error('Could not connect to RabbitMQ after retries');
}

async function publishMessage(queue, message) {
  if (!channel) throw new Error('RabbitMQ channel not initialized');
  channel.sendToQueue(queue, Buffer.from(message), { persistent: true });
  console.log('Published to ' + queue + ': ' + message);
}

module.exports = { connectRabbitMQ, publishMessage };
EOF

echo "  [ok] backend/rabbitmq.js"

# ── backend/auth.js ───────────────────────────────────────────────────────────
cat > backend/auth.js <<'EOF'
const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { pool } = require('./db');

router.post('/register', async (req, res) => {
  const { name, email, password } = req.body;
  if (!name || !email || !password)
    return res.status(400).json({ error: 'name, email, password required' });
  try {
    const hash = await bcrypt.hash(password, 10);
    const result = await pool.query(
      'INSERT INTO users (name, email, password_hash) VALUES ($1, $2, $3) RETURNING id, name, email, created_at',
      [name, email, hash]
    );
    res.status(201).json({ message: 'User registered', user: result.rows[0] });
  } catch (err) {
    if (err.code === '23505')
      return res.status(400).json({ error: 'Email already exists' });
    res.status(500).json({ error: err.message });
  }
});

router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password)
    return res.status(400).json({ error: 'email and password required' });
  try {
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (result.rows.length === 0)
      return res.status(401).json({ error: 'User not found' });
    const user = result.rows[0];
    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid)
      return res.status(401).json({ error: 'Invalid password' });
    const token = jwt.sign(
      { id: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: '2h' }
    );
    res.json({ token, user: { id: user.id, name: user.name, email: user.email } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
EOF

echo "  [ok] backend/auth.js"

# ── backend/server.js ─────────────────────────────────────────────────────────
cat > backend/server.js <<'EOF'
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
EOF

echo "  [ok] backend/server.js"

# ── consumer/.env ─────────────────────────────────────────────────────────────
cat > consumer/.env <<EOF
RABBITMQ_URL=amqp://guest:guest@rabbitmq_${ROLL}:5672
QUEUE_NAME=event_created_${ROLL}
EOF

echo "  [ok] consumer/.env"

# ── consumer/package.json ─────────────────────────────────────────────────────
cat > consumer/package.json <<'EOF'
{
  "name": "consumer",
  "version": "1.0.0",
  "main": "consumer.js",
  "dependencies": {
    "amqplib": "^0.10.3",
    "dotenv": "^16.0.3"
  }
}
EOF

echo "  [ok] consumer/package.json"

# ── consumer/Dockerfile ───────────────────────────────────────────────────────
cat > consumer/Dockerfile <<'EOF'
FROM node:18-alpine
WORKDIR /app
COPY package.json .
RUN npm install
COPY . .
CMD ["node", "consumer.js"]
EOF

echo "  [ok] consumer/Dockerfile"

# ── consumer/consumer.js ──────────────────────────────────────────────────────
cat > consumer/consumer.js <<'EOF'
require('dotenv').config();
const amqp = require('amqplib');

async function startConsumer() {
  let retries = 20;
  while (retries > 0) {
    try {
      const connection = await amqp.connect(process.env.RABBITMQ_URL);
      const channel = await connection.createChannel();
      await channel.assertQueue(process.env.QUEUE_NAME, { durable: true });
      channel.prefetch(1);
      console.log('[consumer_047] Listening on queue: ' + process.env.QUEUE_NAME);

      channel.consume(process.env.QUEUE_NAME, (msg) => {
        if (msg) {
          const data = JSON.parse(msg.content.toString());
          console.log(
            "[consumer_047] Notification sent: New event '" +
            data.title + "' created in region '" +
            data.region + "' (event_id=" + data.event_id + ")"
          );
          channel.ack(msg);
        }
      });
      return;
    } catch (err) {
      console.log('[consumer_047] RabbitMQ not ready, retrying... (' + retries + ' left)');
      retries--;
      await new Promise(r => setTimeout(r, 5000));
    }
  }
  console.error('[consumer_047] Failed to connect to RabbitMQ');
  process.exit(1);
}

startConsumer();
EOF

echo "  [ok] consumer/consumer.js"

# ── STEP 5: Build and run ─────────────────────────────────────────────────────
echo ""
echo "[5/6] Building and starting containers..."
docker compose up --build -d

echo ""
echo "[6/6] Waiting 35 seconds for services to initialize..."
sleep 35

echo ""
echo "============================================"
echo " Container Status"
echo "============================================"
docker compose ps

# ── STEP 6: Run tests ─────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo " Running Tests"
echo "============================================"

echo ""
echo "--- Health Check ---"
curl -s http://localhost:3000/health | python3 -m json.tool

echo ""
echo "--- Register User ---"
curl -s -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Ali Khan","email":"ali@test.com","password":"pass123"}' | python3 -m json.tool

echo ""
echo "--- Login User ---"
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"ali@test.com","password":"pass123"}')
echo $LOGIN_RESPONSE | python3 -m json.tool

TOKEN=$(echo $LOGIN_RESPONSE | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])" 2>/dev/null)
echo ""
echo "Token captured: ${TOKEN:0:40}..."

echo ""
echo "--- Create Event (JWT Protected) ---"
curl -s -X POST http://localhost:3000/events/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"title\":\"Tech Summit ${ROLL}\",\"description\":\"Annual cloud computing summit\",\"region\":\"us-east-1\"}" | python3 -m json.tool

echo ""
echo "--- View Events ---"
curl -s http://localhost:3000/events | python3 -m json.tool

echo ""
echo "--- View Logs ---"
curl -s http://localhost:3000/logs | python3 -m json.tool

echo ""
echo "--- Consumer Notification ---"
sleep 3
docker logs consumer_${ROLL} 2>&1 | tail -10

echo ""
echo "============================================"
echo " SETUP COMPLETE"
echo "============================================"
echo "Backend:          http://localhost:3000"
echo "RabbitMQ UI:      http://localhost:15672  (guest / guest)"
echo "Health:           curl http://localhost:3000/health"
echo "Logs:             docker compose logs -f"
echo "Stop:             docker compose down"
echo "============================================"
