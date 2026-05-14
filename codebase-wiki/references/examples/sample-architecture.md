# Architecture

`acme-billing-api` is a stateless TypeScript HTTP API that processes subscription billing events for multi-tenant SaaS customers. It runs as a horizontally-scalable service behind a load balancer, backed by PostgreSQL for primary state and Redis for short-lived job coordination.

## System shape

```
                +-------------+
                |  Customer   |
                |   Client    |
                +------+------+
                       |
                       v
                +------+-------+
                | Load Balancer |
                +------+-------+
                       |
        +--------------+--------------+
        |              |              |
        v              v              v
   +----+----+    +----+----+    +----+----+
   |   API   |    |   API   |    |   API   |
   |  Worker |    |  Worker |    |  Worker |
   +----+----+    +----+----+    +----+----+
        |              |              |
        +--------------+--------------+
                       |
       +---------------+---------------+
       |                               |
       v                               v
+------+------+               +--------+--------+
|  PostgreSQL  |               |     Redis      |
|  (primary)   |               | (queue, lock)  |
+--------------+               +--------+-------+
                                        |
                                        v
                              +---------+--------+
                              |  Stripe / PayPal |
                              |  (outbound HTTP) |
                              +------------------+
```

Each API process is identical and stateless. Requests can land on any instance. Coordination across instances happens through Redis (job queue, distributed locks) and PostgreSQL (durable state).

## Major components

| Component | Path | Owns |
|-----------|------|------|
| HTTP layer | `src/api/` | Route registration, middleware, request and response shaping |
| Auth | `src/auth/` | Sessions, API keys, scope enforcement |
| Billing core | `src/billing/` | Subscription lifecycle, invoicing, proration |
| Payment providers | `src/providers/` | Stripe and PayPal client integration |
| Job runner | `src/jobs/` | Background work (charge retries, dunning) |
| Data | `src/db/` | Repository pattern over PostgreSQL; migrations |
| Shared | `src/lib/` | Crypto, logging, error types |

## Runtime shape

Process boot in `src/server.ts:1-45`:

1. Load config from environment (`src/config/`).
2. Open the PostgreSQL pool (`src/db/pool.ts`).
3. Open the Redis client (`src/lib/redis.ts`).
4. Register routes (`src/api/routes/index.ts`).
5. Start the HTTP listener.

Background jobs run in a separate entrypoint, `src/jobs/worker.ts`, which dequeues from Redis and dispatches to handlers in `src/jobs/handlers/`.

## External dependencies

- **PostgreSQL 15+** — durable state. Migrations in `db/migrations/`.
- **Redis 6+** — job queue and distributed locks.
- **Stripe API** — primary payment provider. Wrapped by `src/providers/stripe/`.
- **PayPal API** — secondary provider. `src/providers/paypal/`.

## Deployment

Each API worker is a containerized Node 20 process. Jobs run as separate worker pods. See `infrastructure/` and `.github/workflows/deploy.yml`.

## Architectural constraints

- **Stateless workers.** Anything that survives a request must live in PostgreSQL or Redis. Local in-memory caches are tolerated only for read-only config.
- **No direct provider calls outside `src/providers/`.** Other modules import the abstract provider interface, not the SDK. Keeps the system swappable.
- **All money math goes through `src/billing/money.ts`.** Hand-rolled cents arithmetic is banned to avoid float rounding.

---

Back to [README](README.md) · Next: [Module Map](module-map.md)
