# CE408L Cloud Computing Lab — Final Exam
### Lightweight Lakehouse Logging · Spring 2026

![Node.js](https://img.shields.io/badge/Node.js-18-green?logo=node.js)
![Express](https://img.shields.io/badge/Express.js-4.18-black?logo=express)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue?logo=postgresql)
![RabbitMQ](https://img.shields.io/badge/RabbitMQ-3--management-orange?logo=rabbitmq)
![Docker](https://img.shields.io/badge/Docker-Compose-blue?logo=docker)
![JWT](https://img.shields.io/badge/Auth-JWT-purple?logo=jsonwebtokens)
![Status](https://img.shields.io/badge/Status-Passing-brightgreen)

---

## Student Info

| Field | Value |
|---|---|
| **Student** | Affan Bin Saeed |
| **Roll Number** | u047 |
| **Course** | CE408L — Cloud Computing Lab |
| **Exam** | Final Term — Lightweight Lakehouse Logging |
| **Date** | 12 May 2026 |
| **Instructor** | Safia Baloch |
| **Institute** | GIK Institute of Engineering Sciences and Technology |

---

## Overview

Microservices-based event management backend deployed on AWS CloudShell using Docker Compose. Simulates a lightweight lakehouse ingestion workflow — every event created is logged asynchronously via RabbitMQ and stored for future analytical processing.

---

## System Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                        CLIENT                                │
│                    (curl / REST)                             │
└─────────────────────────┬────────────────────────────────────┘
                          │ HTTP :3000
                          ▼
┌──────────────────────────────────────────────────────────────┐
│                    backend_047                               │
│               Express.js · Node 18                          │
│                                                              │
│  POST /auth/register   →  bcrypt hash → PostgreSQL          │
│  POST /auth/login      →  bcrypt verify → JWT issued        │
│  POST /events/create   →  JWT middleware → DB + MQ publish  │
│  GET  /events          →  PostgreSQL query + JOIN           │
│  GET  /logs            →  event_logs table (lakehouse)      │
│  GET  /health          →  service status                    │
└────────────┬─────────────────────────┬───────────────────────┘
             │ pg pool                 │ amqplib publish
             ▼                         ▼
┌────────────────────┐    ┌────────────────────────────────────┐
│   postgres_047     │    │          rabbitmq_047              │
│   PostgreSQL 15    │    │     RabbitMQ 3 + Management UI     │
│   port: 5432       │    │     port: 5672 · mgmt: 15672       │
│                    │    │                                    │
│  ┌──────────────┐  │    │  queue: event_created_047          │
│  │    users     │  │    └──────────────┬─────────────────────┘
│  ├──────────────┤  │                   │ amqplib consume
│  │    events    │  │                   ▼
│  ├──────────────┤  │    ┌────────────────────────────────────┐
│  │ event_logs   │  │    │         consumer_047               │
│  └──────────────┘  │    │   Async notification service       │
└────────────────────┘    │   Prints: "Notification sent: ..." │
                          └────────────────────────────────────┘
```

---

## Docker Resources

> All resources named with roll number suffix `_047` per exam requirement.

| Resource | Name | Port |
|---|---|---|
| PostgreSQL container | `postgres_047` | 5432 |
| RabbitMQ container | `rabbitmq_047` | 5672, 15672 |
| Backend container | `backend_047` | 3000 |
| Consumer container | `consumer_047` | — |
| Docker network | `event_net_047` | — |
| Docker volume | `postgres_data_047` | — |
| RabbitMQ queue | `event_created_047` | — |
| Database | `eventdb_047` | — |

---

## Project Structure

```
event-platform-047/
├── docker-compose.yml          # Orchestrates all 4 services
├── backend/
│   ├── server.js               # Express app, routes, JWT middleware
│   ├── db.js                   # PostgreSQL pool + auto table init
│   ├── auth.js                 # Register / Login routes
│   ├── rabbitmq.js             # RabbitMQ connect + publish
│   ├── package.json
│   ├── Dockerfile
│   └── .env
└── consumer/
    ├── consumer.js             # Queue listener + notification logger
    ├── package.json
    ├── Dockerfile
    └── .env
```

---

## Database Schema

```sql
CREATE TABLE users (
  id            SERIAL PRIMARY KEY,
  name          VARCHAR(255),
  email         VARCHAR(255) UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at    TIMESTAMP DEFAULT NOW()
);

CREATE TABLE events (
  id          SERIAL PRIMARY KEY,
  title       VARCHAR(255),
  description TEXT,
  region      VARCHAR(100),
  created_by  INTEGER REFERENCES users(id),
  created_at  TIMESTAMP DEFAULT NOW()
);

CREATE TABLE event_logs (
  id         SERIAL PRIMARY KEY,
  event_id   INTEGER,
  action     VARCHAR(100),
  message    TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);
```

> Tables auto-created on backend startup — no manual SQL required.

---

## Quick Start

```bash
# Clone
git clone https://github.com/AffnKhn/CLOUD_FINAL_u047.git
cd CLOUD_FINAL_u047/event-platform-047

# Install Docker (Ubuntu/EC2)
sudo apt update -y && sudo apt install -y docker.io docker-compose-plugin
sudo systemctl start docker
sudo usermod -aG docker $USER && newgrp docker

# Run all 4 containers
DOCKER_BUILDKIT=0 docker compose up --build -d

# Verify
docker compose ps
```

> Or run the automated script: `bash setup.sh`

---

## API Reference

### Public Routes

| Method | Endpoint | Body | Response |
|---|---|---|---|
| GET | `/health` | — | `{status, service, timestamp}` |
| POST | `/auth/register` | `{name, email, password}` | `{message, user}` |
| POST | `/auth/login` | `{email, password}` | `{token, user}` |
| GET | `/events` | — | `{count, events[]}` |
| GET | `/logs` | — | `{count, logs[]}` |

### Protected Routes (requires `Authorization: Bearer <token>`)

| Method | Endpoint | Body | Response |
|---|---|---|---|
| POST | `/events/create` | `{title, description, region}` | `{message, event}` |

---

## Test Commands

```bash
# Health
curl http://localhost:3000/health

# Register
curl -s -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Ali Khan","email":"ali047@test.com","password":"pass123"}' \
  | python3 -m json.tool

# Login + save token
TOKEN=$(curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"ali047@test.com","password":"pass123"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

# Create event (JWT protected)
curl -s -X POST http://localhost:3000/events/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title":"Tech Summit 047","description":"Cloud summit","region":"us-east-1"}' \
  | python3 -m json.tool

# View events
curl -s http://localhost:3000/events | python3 -m json.tool

# View logs
curl -s http://localhost:3000/logs | python3 -m json.tool

# Consumer notification
docker logs consumer_047

# RabbitMQ queue status
curl -s -u guest:guest http://localhost:15672/api/queues/%2F/event_created_047 \
  | python3 -m json.tool
```

---

## Live Test Results

All tests passed on AWS CloudShell · 12 May 2026

| # | Test | Result |
|---|------|--------|
| 1 | Docker compose up | `[+] up 8/8` all healthy |
| 2 | GET /health | `status: ok, service: backend_047` |
| 3 | POST /auth/register | User created, `id=2` |
| 4 | POST /auth/login | JWT token issued (HS256, 2h expiry) |
| 5 | POST /events/create | Event created, JWT auth passed |
| 6 | GET /events | 2 events returned with creator JOIN |
| 7 | GET /logs | 2 lakehouse log entries |
| 8 | docker logs consumer_047 | Notification printed for both events |
| 9 | RabbitMQ HTTP API | `publish:1, ack:1, consumers:1, state:running` |

---

## CLO Achievement

**CLO_3:** Design and develop scalable backend services using modern backend technologies and distributed systems concepts. *(Cognitive Level C6 — Create)*

| Requirement | Implementation | Status |
|---|---|---|
| Authentication Service | `/auth/register` + `/auth/login` · bcrypt + JWT | ✅ |
| Event Service | `/events/create` (JWT) + `/events` · PostgreSQL | ✅ |
| Notification/Consumer Service | `consumer_047` · RabbitMQ async | ✅ |
| Lakehouse Event Logs | `event_logs` table + `/logs` endpoint | ✅ |
| PostgreSQL | `postgres_047` · 3 tables auto-init | ✅ |
| RabbitMQ | `rabbitmq_047` · queue `event_created_047` | ✅ |
| Docker Compose | 4 services · healthchecks · network · volume | ✅ |
| Roll number naming | All resources suffixed `_047` | ✅ |

---

## Troubleshooting

| Error | Fix |
|---|---|
| `compose build requires buildx 0.17.0` | `DOCKER_BUILDKIT=0 docker compose up --build -d` |
| `permission denied` on Docker | `sudo usermod -aG docker $USER && newgrp docker` |
| Port already in use | `sudo lsof -i :3000` → `sudo kill -9 <PID>` |
| RabbitMQ connection refused | Wait 30s — consumer retries 20× automatically |
| JWT invalid | Re-login: `TOKEN=$(curl ... login ...)` |
| Container restart loop | `docker logs backend_047` — usually DB not ready yet |

---

## Repository Contents

| File | Description |
|---|---|
| `event-platform-047/` | Full microservices project |
| `setup.sh` | Automated one-command deploy script |
| `EVIDENCE_CC_FINAL.docx` | Exam evidence document |
| `CC_FINAL.jpeg` | Exam paper |
| `EVIDENCE.md` | All live terminal outputs with analysis |
| `WORKFLOW_LOG.md` | Step-by-step implementation timeline |

---

*GIK Institute · CE408L Cloud Computing Lab · Spring 2026*
