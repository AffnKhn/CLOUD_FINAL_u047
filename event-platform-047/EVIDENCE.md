# CE408L Final Exam — Live Evidence Document
**Student:** u047 | **Exam:** Lightweight Lakehouse Logging | **Date:** 12 May 2026
**GitHub:** https://github.com/AffnKhn/CLOUD_FINAL_u047

---

## Evidence 1 — Docker Build & All Containers Running

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

**Containers:** `postgres_047`, `rabbitmq_047`, `backend_047`, `consumer_047`
**Network:** `event_net_047`
**Volume:** `postgres_data_047`

---

## Evidence 2 — Health Check

**Command:**
```bash
curl http://localhost:3000/health
```

**Output:**
```json
{"status":"ok","service":"backend_047","timestamp":"2026-05-12T07:52:52.418Z"}
```

**Proves:** Backend container running, Express server responding on port 3000.

---

## Evidence 3 — User Registration (POST /auth/register)

**Command:**
```bash
curl -s -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Ali Khan","email":"ali@test.com","password":"pass123"}' | python3 -m json.tool
```

**Output:**
```json
{
    "message": "User registered",
    "user": {
        "id": 1,
        "name": "Ali Khan",
        "email": "ali@test.com",
        "created_at": "2026-05-12T07:52:52.544Z"
    }
}
```

**Proves:** User stored in PostgreSQL `users` table. Password hashed with bcryptjs (hash not returned). Auto-incremented `id=1`.

---

## Evidence 4 — User Login + JWT Token (POST /auth/login)

**Command:**
```bash
TOKEN=$(curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"ali@test.com","password":"pass123"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

echo "Token: $TOKEN"
```

**Output:**
```
Token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MSwiZW1haWwiOiJhbGlAdGVzdC5jb20iLCJpYXQiOjE3Nzg1NzIzNzIsImV4cCI6MTc3ODU3OTU3Mn0.FAKrft9lcN91LLMosvmWpKAkS9b1ONfUwj54Sbu83Ag
```

**Proves:**
- Password validated against bcrypt hash
- JWT issued using HS256 algorithm
- Token contains `id`, `email`, `iat`, `exp` (2h expiry)
- Token saved to `$TOKEN` for protected route use

---

## Evidence 5 — Create Event with JWT Auth (POST /events/create)

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
        "id": 1,
        "title": "Tech Summit 047",
        "description": "Cloud summit",
        "region": "us-east-1",
        "created_by": 1,
        "created_at": "2026-05-12T07:52:52.697Z"
    }
}
```

**Proves:**
- JWT middleware verified `Authorization: Bearer` token
- Event inserted into PostgreSQL `events` table
- `created_by` linked to user `id=1` (foreign key)
- RabbitMQ message published to `event_created_047`
- Log entry written to `event_logs` table

---

## Evidence 6 — View All Events (GET /events)

**Command:**
```bash
curl -s http://localhost:3000/events | python3 -m json.tool
```

**Output:**
```json
{
    "count": 1,
    "events": [
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

**Proves:**
- Event retrieved from PostgreSQL
- JOIN with `users` table working (`creator_name: "Ali Khan"`)
- Public endpoint (no JWT required)

---

## Evidence 7 — Event Logs / Lakehouse Simulation (GET /logs)

**Command:**
```bash
curl -s http://localhost:3000/logs | python3 -m json.tool
```

**Output:**
```json
{
    "count": 1,
    "logs": [
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

**Proves:**
- `event_logs` table populated on every event creation
- Simulates lakehouse ingestion pipeline log
- `action: "event_created"` — structured for future analytical queries
- Linked to `event_id=1`

---

## Evidence 8 — Consumer Notification via RabbitMQ

**Command:**
```bash
docker logs consumer_047
```

**Output:**
```
[consumer_047] Listening on queue: event_created_047
[consumer_047] Notification sent: New event 'Tech Summit 047' created in region 'us-east-1' (event_id=1)
```

**Proves:**
- `consumer_047` connected to RabbitMQ queue `event_created_047`
- Received message published by backend on event creation
- Asynchronous decoupled notification working
- Message acknowledged (`ack`) after processing

---

## Evidence 9 — RabbitMQ Queue Status (API Proof)

**Command:**
```bash
curl -s -u guest:guest http://localhost:15672/api/queues/%2F/event_created_047 | python3 -m json.tool
```

**Output (key fields):**
```json
{
    "name": "event_created_047",
    "state": "running",
    "durable": true,
    "consumers": 1,
    "messages": 0,
    "message_stats": {
        "publish": 1,
        "ack": 1,
        "deliver": 1
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
            },
            "channel_details": {
                "connection_name": "172.18.0.5:38220 -> 172.18.0.2:5672",
                "user": "guest"
            }
        }
    ]
}
```

**Proves:**
- Queue `event_created_047` exists and is `running`
- `durable: true` — survives RabbitMQ restart
- `consumers: 1` — `consumer_047` actively connected
- `publish: 1` — backend published 1 message
- `deliver: 1` — message delivered to consumer
- `ack: 1` — consumer acknowledged receipt
- `messages: 0` — queue empty (message fully processed)

---

## Summary Table

| # | Test | Endpoint | Result | HTTP Status |
|---|------|----------|--------|-------------|
| 1 | Docker up | — | All 8 resources created | — |
| 2 | Health check | GET /health | `status: ok` | 200 |
| 3 | Register user | POST /auth/register | User id=1 created | 201 |
| 4 | Login + JWT | POST /auth/login | Token issued | 200 |
| 5 | Create event | POST /events/create | Event id=1 created | 201 |
| 6 | View events | GET /events | 1 event, with creator join | 200 |
| 7 | View logs | GET /logs | 1 log entry recorded | 200 |
| 8 | Consumer log | docker logs consumer_047 | Notification printed | — |
| 9 | RabbitMQ queue | HTTP API :15672 | publish=1, ack=1, running | 200 |

**All 9 tests PASSED.**
