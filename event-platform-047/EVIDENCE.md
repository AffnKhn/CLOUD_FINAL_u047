# CE408L Final Exam — Live Evidence Document
**Student:** u047 | **Exam:** Lightweight Lakehouse Logging | **Date:** 12 May 2026
**GitHub:** https://github.com/AffnKhn/CLOUD_FINAL_u047
**Platform:** AWS CloudShell | **Stack:** Node.js · Express · PostgreSQL · RabbitMQ · Docker

---

## Evidence 1 — All 4 Docker Containers Running

**Command:**
```bash
docker compose ps
```

**Output:**
```
NAME           IMAGE                             COMMAND                  SERVICE        CREATED          STATUS                    PORTS
backend_047    event-platform-047-backend_047    "docker-entrypoint.s…"   backend_047    15 minutes ago   Up 15 minutes             0.0.0.0:3000->3000/tcp
consumer_047   event-platform-047-consumer_047   "docker-entrypoint.s…"   consumer_047   15 minutes ago   Up 15 minutes
postgres_047   postgres:15                       "docker-entrypoint.s…"   postgres_047   16 minutes ago   Up 15 minutes (healthy)   0.0.0.0:5432->5432/tcp
rabbitmq_047   rabbitmq:3-management             "docker-entrypoint.s…"   rabbitmq_047   16 minutes ago   Up 15 minutes (healthy)   4369/tcp, 5671/tcp, 0.0.0.0:5672->5672/tcp, 15671/tcp, 15691-15692/tcp, 25672/tcp, 0.0.0.0:15672->15672/tcp
```

**Proves:**
- All 4 containers running on custom network `event_net_047`
- `postgres_047` — healthy, port 5432
- `rabbitmq_047` — healthy, ports 5672 + 15672
- `backend_047` — up, port 3000
- `consumer_047` — up, listening to queue

---

## Evidence 2 — Docker Build Success

**Output:**
```
[+] up 8/8
 ✔ Image event-platform-047-consumer_047       Built                   32.6s
 ✔ Image event-platform-047-backend_047        Built                   44.4s
 ✔ Network event-platform-047_event_net_047    Created                  0.1s
 ✔ Volume event-platform-047_postgres_data_047 Created                  0.0s
 ✔ Container rabbitmq_047                      Healthy                 44.2s
 ✔ Container postgres_047                      Healthy                 38.7s
 ✔ Container consumer_047                      Started                 22.7s
 ✔ Container backend_047                       Started                 21.2s
```

**Proves:** Full Docker Compose stack built and started. Network `event_net_047` and volume `postgres_data_047` created.

---

## Evidence 3 — Health Check

**Command:**
```bash
curl http://localhost:3000/health
```

**Output:**
```json
{"status":"ok","service":"backend_047","timestamp":"2026-05-12T07:52:52.418Z"}
```

**Proves:** Express backend running and responding on port 3000.

---

## Evidence 4 — User Registration (POST /auth/register)

**Command:**
```bash
curl -s -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Ali Khan","email":"ali047@test.com","password":"pass123"}' | python3 -m json.tool
```

**Output:**
```json
{
    "message": "User registered",
    "user": {
        "id": 2,
        "name": "Ali Khan",
        "email": "ali047@test.com",
        "created_at": "2026-05-12T08:10:26.058Z"
    }
}
```

**Proves:** User inserted into PostgreSQL `users` table. Password hashed with bcryptjs — hash not exposed in response.

---

## Evidence 5 — User Login + JWT Token (POST /auth/login)

**Command:**
```bash
curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"ali047@test.com","password":"pass123"}' | python3 -m json.tool
```

**Output:**
```json
{
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MiwiZW1haWwiOiJhbGkwNDdAdGVzdC5jb20iLCJpYXQiOjE3Nzg1NzM1OTEsImV4cCI6MTc3ODU4MDc5MX0._tf7rjHIVqllpDRE1-2q0CyuGrnNbEMqiI8uFatASJ0",
    "user": {
        "id": 2,
        "name": "Ali Khan",
        "email": "ali047@test.com"
    }
}
```

**Proves:** bcrypt hash validated. JWT issued with HS256, contains `id`, `email`, `iat`, `exp` (2h expiry).

---

## Evidence 6 — JWT Token Saved to Variable

**Command:**
```bash
TOKEN=$(curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"ali047@test.com","password":"pass123"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")
echo $TOKEN
```

**Output:**
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MiwiZW1haWwiOiJhbGkwNDdAdGVzdC5jb20iLCJpYXQiOjE3Nzg1NzM3OTQsImV4cCI6MTc3ODU4MDk5NH0.BQoQlAFwiu3wkXYQ5hEZz7D7otky-5iQ3gObaOWaMnI
```

**Proves:** Token extracted and stored in `$TOKEN` shell variable for use in protected routes.

---

## Evidence 7 — Create Event with JWT Auth (POST /events/create)

**Command:**
```bash
curl -s -X POST http://localhost:3000/events/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title":"Tech Summit 047","description":"Cloud summit","region":"us-east-1"}' | python3 -m json.tool
```

**Output:**
```json
{
    "message": "Event created",
    "event": {
        "id": 2,
        "title": "Tech Summit 047",
        "description": "Cloud summit",
        "region": "us-east-1",
        "created_by": 2,
        "created_at": "2026-05-12T08:17:39.061Z"
    }
}
```

**Proves:**
- JWT middleware verified Bearer token
- Event inserted into PostgreSQL `events` table
- `created_by: 2` — foreign key to authenticated user
- RabbitMQ message published to `event_created_047`
- Log entry written to `event_logs`

---

## Evidence 8 — View All Events (GET /events)

**Command:**
```bash
curl -s http://localhost:3000/events | python3 -m json.tool
```

**Output:**
```json
{
    "count": 2,
    "events": [
        {
            "id": 2,
            "title": "Tech Summit 047",
            "description": "Cloud summit",
            "region": "us-east-1",
            "created_by": 2,
            "created_at": "2026-05-12T08:17:39.061Z",
            "creator_name": "Ali Khan"
        },
        {
            "id": 1,
            "title": "Tech Summit 047",
            "description": "Cloud summit",
            "region": "us-east-1",
            "created_by": 1,
            "created_at": "2026-05-12T07:52:52.697Z",
            "creator_name": "Ali Khan"
        }
    ]
}
```

**Proves:** Events retrieved from PostgreSQL. JOIN with `users` table returns `creator_name`. Persistent across sessions.

---

## Evidence 9 — Event Logs / Lakehouse Ingestion (GET /logs)

**Command:**
```bash
curl -s http://localhost:3000/logs | python3 -m json.tool
```

**Output:**
```json
{
    "count": 2,
    "logs": [
        {
            "id": 2,
            "event_id": 2,
            "action": "event_created",
            "message": "Event \"Tech Summit 047\" created in region \"us-east-1\" by user 2",
            "created_at": "2026-05-12T08:17:39.064Z"
        },
        {
            "id": 1,
            "event_id": 1,
            "action": "event_created",
            "message": "Event \"Tech Summit 047\" created in region \"us-east-1\" by user 1",
            "created_at": "2026-05-12T07:52:52.700Z"
        }
    ]
}
```

**Proves:** `event_logs` table auto-populated on every event creation. Simulates lakehouse ingestion pipeline. Structured for analytical processing (`action`, `event_id`, `message`, `timestamp`).

---

## Evidence 10 — Consumer Notification via RabbitMQ

**Command:**
```bash
docker logs consumer_047
```

**Output:**
```
[consumer_047] Listening on queue: event_created_047
[consumer_047] Notification sent: New event 'Tech Summit 047' created in region 'us-east-1' (event_id=1)
[consumer_047] Notification sent: New event 'Tech Summit 047' created in region 'us-east-1' (event_id=2)
```

**Proves:** `consumer_047` receives and processes every message published by backend. Async decoupled notification working end-to-end.

---

## Evidence 11 — RabbitMQ Queue Proof (HTTP API)

**Command:**
```bash
curl -s -u guest:guest http://localhost:15672/api/queues/%2F/event_created_047 | python3 -m json.tool
```

**Key Output:**
```json
{
    "name": "event_created_047",
    "state": "running",
    "durable": true,
    "consumers": 1,
    "messages": 0,
    "message_stats": {
        "publish": 1,
        "deliver": 1,
        "ack": 1
    },
    "consumer_details": [
        {
            "active": true,
            "activity_status": "up",
            "ack_required": true,
            "prefetch_count": 1,
            "queue": {
                "name": "event_created_047",
                "vhost": "/"
            }
        }
    ]
}
```

**Proves:**
- Queue `event_created_047` exists and `state: running`
- `durable: true` — persists across restarts
- `consumers: 1` — consumer_047 actively connected
- `publish: 1` — backend published message
- `deliver: 1` — delivered to consumer
- `ack: 1` — consumer acknowledged
- `messages: 0` — fully processed, queue empty

---

## Final Summary

| # | Evidence | Command | Result |
|---|----------|---------|--------|
| 1 | 4 containers running | `docker compose ps` | All Up + Healthy |
| 2 | Docker build success | `docker compose up --build` | `[+] up 8/8` |
| 3 | Health check | `GET /health` | `status: ok` |
| 4 | Register user | `POST /auth/register` | User id=2 created |
| 5 | Login + JWT | `POST /auth/login` | Token issued (HS256) |
| 6 | Token saved | `echo $TOKEN` | Token in shell variable |
| 7 | Create event (JWT) | `POST /events/create` | Event id=2, auth passed |
| 8 | View events | `GET /events` | 2 events, JOIN working |
| 9 | View logs | `GET /logs` | 2 lakehouse log entries |
| 10 | Consumer notification | `docker logs consumer_047` | Notifications printed |
| 11 | RabbitMQ queue | HTTP API `:15672` | publish=1, ack=1, running |

**All 11 evidence points PASSED.**
