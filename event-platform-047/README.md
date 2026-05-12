# CE408L Cloud Computing Lab — Final Exam
## Lightweight Lakehouse Logging — Event Platform
**Student Roll:** u047 | **Date:** 12 May 2026 | **Instructor:** Safia Baloch

---

## System Architecture

```
┌─────────────┐    JWT     ┌──────────────────────────────────────┐
│   Client    │ ─────────► │           backend_047                │
│  (curl/UI)  │            │         Express.js :3000             │
└─────────────┘            │                                      │
                           │  POST /auth/register                 │
                           │  POST /auth/login                    │
                           │  POST /events/create  (JWT required) │
                           │  GET  /events                        │
                           │  GET  /logs                          │
                           │  GET  /health                        │
                           └──────┬───────────────┬──────────────┘
                                  │               │
                         pg pool  │               │ amqplib publish
                                  ▼               ▼
                      ┌─────────────────┐  ┌─────────────────────┐
                      │  postgres_047   │  │   rabbitmq_047      │
                      │  :5432         │  │   :5672 / :15672    │
                      │                │  │   queue:            │
                      │  users         │  │   event_created_047 │
                      │  events        │  └──────────┬──────────┘
                      │  event_logs    │             │ consume
                      └─────────────────┘            ▼
                                           ┌──────────────────────┐
                                           │   consumer_047       │
                                           │   Prints notification│
                                           └──────────────────────┘
```

---

## Project Structure

```
event-platform-047/
├── docker-compose.yml
├── backend/
│   ├── .env
│   ├── package.json
│   ├── Dockerfile
│   ├── server.js       ← Express app, routes, JWT middleware
│   ├── db.js           ← PostgreSQL pool + table init
│   ├── auth.js         ← Register/Login routes
│   └── rabbitmq.js     ← Connect + publish to RabbitMQ
└── consumer/
    ├── .env
    ├── package.json
    ├── Dockerfile
    └── consumer.js     ← Listens to queue, logs notifications
```

---

## Docker Resources (all named with roll suffix _047)

| Resource | Name |
|---|---|
| PostgreSQL container | `postgres_047` |
| RabbitMQ container | `rabbitmq_047` |
| Backend container | `backend_047` |
| Consumer container | `consumer_047` |
| Docker network | `event_net_047` |
| PostgreSQL volume | `postgres_data_047` |
| RabbitMQ queue | `event_created_047` |
| Database name | `eventdb_047` |

---

## Database Schema

```sql
-- Users table
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Events table
CREATE TABLE IF NOT EXISTS events (
  id SERIAL PRIMARY KEY,
  title VARCHAR(255),
  description TEXT,
  region VARCHAR(100),
  created_by INTEGER REFERENCES users(id),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Event logs table (lakehouse ingestion simulation)
CREATE TABLE IF NOT EXISTS event_logs (
  id SERIAL PRIMARY KEY,
  event_id INTEGER,
  action VARCHAR(100),
  message TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);
```

> Tables auto-created on backend startup. No manual SQL required.

---

## Setup & Run

### On Ubuntu EC2 / AWS Terminal

```bash
# Clone repo
git clone https://github.com/AffnKhn/CLOUD_FINAL_u047.git
cd CLOUD_FINAL_u047/event-platform-047

# Install Docker if missing
sudo apt update -y && sudo apt install -y docker.io docker-compose-plugin
sudo systemctl start docker
sudo usermod -aG docker $USER && newgrp docker

# Build and run all 4 containers
docker compose up --build -d

# Check status (wait ~30s for RabbitMQ)
docker compose ps
```

**Or run the automated setup script:**
```bash
bash setup.sh
```

---

## API Endpoints

| Method | Route | Auth | Description |
|---|---|---|---|
| GET | `/health` | No | Service health check |
| POST | `/auth/register` | No | Register new user |
| POST | `/auth/login` | No | Login, returns JWT |
| POST | `/events/create` | Bearer JWT | Create event + publish to queue |
| GET | `/events` | No | List all events |
| GET | `/logs` | No | List all event logs |

---

## Test Commands (curl)

```bash
# 1. Health check
curl http://localhost:3000/health

# 2. Register
curl -s -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Ali Khan","email":"ali@test.com","password":"pass123"}' \
  | python3 -m json.tool

# 3. Login
curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"ali@test.com","password":"pass123"}' \
  | python3 -m json.tool

# 4. Save token
TOKEN=$(curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"ali@test.com","password":"pass123"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

# 5. Create event (JWT protected)
curl -s -X POST http://localhost:3000/events/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title":"Tech Summit 047","description":"Cloud summit","region":"us-east-1"}' \
  | python3 -m json.tool

# 6. View events
curl -s http://localhost:3000/events | python3 -m json.tool

# 7. View logs
curl -s http://localhost:3000/logs | python3 -m json.tool

# 8. Consumer notification
docker logs consumer_047

# 9. RabbitMQ UI
# Open: http://<EC2-PUBLIC-IP>:15672  (guest / guest)
```

---

## Workflow Log

| Step | Action | Key Decision |
|---|---|---|
| 1 | Provisioned Ubuntu EC2 | Docker needs full VM — CloudShell lacks Docker daemon |
| 2 | Installed Docker + Docker Compose plugin | `apt install docker.io docker-compose-plugin` |
| 3 | Designed 4-service architecture | Separated consumer from backend for async decoupling |
| 4 | Created PostgreSQL schema | Tables auto-init in `db.js` using `CREATE TABLE IF NOT EXISTS` |
| 5 | Implemented JWT auth | `bcryptjs` for hashing, `jsonwebtoken` for sign/verify |
| 6 | Implemented event creation | Protected route → DB insert → log insert → RabbitMQ publish |
| 7 | Added RabbitMQ retry logic | Both backend and consumer retry 15-20x with 5s delay |
| 8 | Added DB connection retry | Healthcheck + retry loop ensures tables init after PG ready |
| 9 | Configured Docker Compose healthchecks | `depends_on` with `condition: service_healthy` for startup order |
| 10 | Named all resources with `_047` suffix | Exam requirement: roll number in all resource names |

---

## Screenshot Checklist (for submission)

- [ ] `docker compose ps` — all 4 containers running
- [ ] `curl /auth/register` — 201 response with user object
- [ ] `curl /auth/login` — response with JWT token
- [ ] `echo $TOKEN` — token variable saved
- [ ] `curl /events/create` — 201 response with event object
- [ ] `curl /events` — list of events
- [ ] `curl /logs` — event_logs table entries
- [ ] `docker logs consumer_047` — notification printed
- [ ] RabbitMQ UI at `:15672` — queue `event_created_047` visible

---

## Troubleshooting

| Error | Fix |
|---|---|
| `permission denied` (Docker) | `sudo usermod -aG docker $USER && newgrp docker` |
| Port already in use | `sudo lsof -i :3000` then `sudo kill -9 <PID>` |
| RabbitMQ connection refused | Wait — it takes ~30s. Consumer retries automatically |
| Backend restart loop | `docker logs backend_047` — usually DB/RabbitMQ not ready yet |
| JWT invalid | Token expired → re-login and save fresh `$TOKEN` |
| npm package missing | `docker compose build --no-cache` |
| CloudShell no Docker | Use EC2 Ubuntu instance instead |
