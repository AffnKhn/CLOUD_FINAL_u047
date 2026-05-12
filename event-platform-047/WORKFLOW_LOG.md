# CE408L Final Exam — Workflow & Event Log
**Student:** u047 | **Date:** 12 May 2026 | **Exam:** Lightweight Lakehouse Logging

---

## Timeline of Events

### Phase 1 — Environment Setup

| Time | Action | Result |
|------|--------|--------|
| T+00 | Provisioned Ubuntu EC2 instance | AWS Linux VM ready |
| T+01 | Ran `docker --version` | Docker installed (checked) |
| T+02 | Ran `docker compose version` | Compose plugin present |
| T+03 | Created project folder `event-platform-047/` | Directory structure ready |

---

### Phase 2 — Project File Creation

| File | Purpose | Key Details |
|------|---------|-------------|
| `docker-compose.yml` | Orchestrate 4 containers | Network: `event_net_047`, Volume: `postgres_data_047` |
| `backend/.env` | Backend environment config | DB, JWT secret, RabbitMQ URL, queue name all use `_047` suffix |
| `backend/package.json` | Node dependencies | express, pg, bcryptjs, jsonwebtoken, amqplib, cors, dotenv |
| `backend/Dockerfile` | Build backend image | node:18-alpine, WORKDIR /app |
| `backend/db.js` | PostgreSQL pool + table init | Auto-creates users, events, event_logs on startup with retry loop |
| `backend/rabbitmq.js` | RabbitMQ connection + publish | 15 retries × 5s = 75s patience window |
| `backend/auth.js` | Register + Login routes | bcryptjs hash, JWT sign with 2h expiry |
| `backend/server.js` | Main Express app | JWT middleware, all routes, startup orchestration |
| `consumer/.env` | Consumer environment config | Points to `rabbitmq_047`, queue `event_created_047` |
| `consumer/package.json` | Consumer dependencies | amqplib, dotenv only |
| `consumer/Dockerfile` | Build consumer image | node:18-alpine |
| `consumer/consumer.js` | RabbitMQ listener | 20 retries × 5s, prints notification on message receive |

---

### Phase 3 — Git & GitHub

| Step | Command | Result |
|------|---------|--------|
| Init repo | `git init` | Initialized in `CLOUD_FINAL/` |
| Stage files | `git add event-platform-047/ setup.sh .gitignore` | 15 files staged |
| Commit | `git commit -m "CE408L Final Exam - Event Platform u047..."` | `0adacdc` root commit |
| Add remote | `git remote add origin https://github.com/AffnKhn/CLOUD_FINAL_u047.git` | Remote set |
| Auth | `gh auth setup-git` | Used existing GitHub CLI session (AffnKhn) |
| Push | `git push -u origin main` | `* [new branch] main -> main` — success |

**Repo:** https://github.com/AffnKhn/CLOUD_FINAL_u047

---

### Phase 4 — Docker Build & Run

| Step | Command | Result |
|------|---------|--------|
| First attempt | `docker compose up --build -d` | Failed: `compose build requires buildx 0.17.0 or later` |
| Fix | `DOCKER_BUILDKIT=0 docker compose up --build -d` | Bypassed buildx, used legacy builder |
| postgres_047 | Pulled `postgres:15` | Healthy after 38.7s |
| rabbitmq_047 | Pulled `rabbitmq:3-management` | Healthy after 44.2s |
| consumer_047 | Built from `./consumer` | Started in 32.6s |
| backend_047 | Built from `./backend` | Started in 44.4s |
| Final status | `[+] up 8/8` | All containers running |

**Issue encountered:** `compose build requires buildx 0.17.0 or later`
**Fix applied:** Prepend `DOCKER_BUILDKIT=0` to bypass buildx requirement and use legacy Docker builder

---

### Phase 5 — Live Testing (All Passed)

#### Test 1 — Health Check
```
GET http://localhost:3000/health
→ {"status":"ok","service":"backend_047","timestamp":"2026-05-12T07:52:52.418Z"}
```
**Status:** PASS

---

#### Test 2 — Register User
```
POST http://localhost:3000/auth/register
Body: {"name":"Ali Khan","email":"ali@test.com","password":"pass123"}
→ {"message":"User registered","user":{"id":1,"name":"Ali Khan","email":"ali@test.com","created_at":"2026-05-12T07:52:52.544Z"}}
```
**Status:** PASS | User id=1 created in PostgreSQL

---

#### Test 3 — Login + JWT
```
POST http://localhost:3000/auth/login
Body: {"email":"ali@test.com","password":"pass123"}
→ JWT token issued: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```
**Status:** PASS | Token saved to `$TOKEN` variable

---

#### Test 4 — Create Event (JWT Protected)
```
POST http://localhost:3000/events/create
Authorization: Bearer <token>
Body: {"title":"Tech Summit 047","description":"Cloud summit","region":"us-east-1"}
→ {"message":"Event created","event":{"id":1,"title":"Tech Summit 047","region":"us-east-1","created_by":1,...}}
```
**Status:** PASS | Event inserted + log written + RabbitMQ message published

---

#### Test 5 — View Events
```
GET http://localhost:3000/events
→ {"count":1,"events":[{"id":1,"title":"Tech Summit 047","region":"us-east-1","creator_name":"Ali Khan",...}]}
```
**Status:** PASS | JOIN with users table working

---

#### Test 6 — View Event Logs (Lakehouse Simulation)
```
GET http://localhost:3000/logs
→ {"count":1,"logs":[{"id":1,"event_id":1,"action":"event_created","message":"Event \"Tech Summit 047\" created in region \"us-east-1\" by user 1",...}]}
```
**Status:** PASS | Lakehouse ingestion log recorded

---

#### Test 7 — Consumer Notification
```
docker logs consumer_047
→ [consumer_047] Listening on queue: event_created_047
→ [consumer_047] Notification sent: New event 'Tech Summit 047' created in region 'us-east-1' (event_id=1)
```
**Status:** PASS | Async notification via RabbitMQ confirmed

---

## Docker Resources Summary

| Resource Type | Name |
|---|---|
| Container | `postgres_047` |
| Container | `rabbitmq_047` |
| Container | `backend_047` |
| Container | `consumer_047` |
| Network | `event_net_047` |
| Volume | `postgres_data_047` |
| RabbitMQ Queue | `event_created_047` |
| Database | `eventdb_047` |
| JWT Secret | `jwt_secret_047` |

---

## Issues Encountered & Fixes

| Issue | Root Cause | Fix |
|---|---|---|
| `compose build requires buildx 0.17.0 or later` | EC2 Docker install had old buildx | `DOCKER_BUILDKIT=0 docker compose up --build -d` |
| `-bash: Health: command not found` | Pasted comment line as command | Harmless — bash tried to run `# Health check` as command |

---

## CLO Achievement

**CLO_3:** Design and develop scalable backend services using modern backend technologies and distributed systems concepts.

| Requirement | Implementation | Status |
|---|---|---|
| Authentication Service | `/auth/register` + `/auth/login` with bcrypt + JWT | DONE |
| Event Service | `/events/create` (JWT protected) + `/events` | DONE |
| Notification Service | `consumer_047` on RabbitMQ queue | DONE |
| Event Logs / Lakehouse | `event_logs` table + `/logs` endpoint | DONE |
| PostgreSQL | `postgres_047` container, 3 tables | DONE |
| RabbitMQ | `rabbitmq_047` container, queue `event_created_047` | DONE |
| Docker Compose | 4 services, healthchecks, network, volume | DONE |
| Roll number naming | All resources suffixed `_047` | DONE |
