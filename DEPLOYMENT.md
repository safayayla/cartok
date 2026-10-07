# Deployment

## Prerequisites

- PostgreSQL 16+ (managed service recommended in production — RDS, Cloud SQL, etc.)
- Redis 7+ (managed service recommended — ElastiCache, Memorystore, etc.)
- Node.js 20+ (for building; the runtime image is Alpine-based)
- A container registry, if deploying via Docker (not yet wired into CI — see below)

## Required environment variables

All validated at startup by `backend/src/config/env.ts` — the process
refuses to boot if any required value is missing or malformed, rather than
silently running with broken config.

| Variable | Required | Notes |
|---|---|---|
| `NODE_ENV` | no (default `development`) | Set to `production` in prod — this also toggles error-message masking and log verbosity. |
| `PORT` | no (default `4000`) | |
| `DATABASE_URL` | **yes** | Postgres connection string. |
| `REDIS_URL` | **yes** | Used for distributed rate limiting. |
| `JWT_ACCESS_SECRET` | **yes**, min 32 chars | Generate with `openssl rand -hex 32`. Rotating this invalidates all outstanding access tokens (users get a 401 and transparently re-authenticate via refresh). |
| `ACCESS_TOKEN_TTL` | no (default `15m`) | |
| `REFRESH_TOKEN_TTL_DAYS` | no (default `30`) | |
| `CORS_ORIGINS` | no (default `http://localhost:3000`) | **Comma-separated exact origins. Never a wildcard** — required for cookie-credentialed requests to work at all, and the right default regardless. |
| `COOKIE_DOMAIN` | no | Set if the API and any web frontend share a parent domain. |
| `NHTSA_VIN_API_BASE` | no | Only change for testing against a mock. |

Note: there is intentionally no `JWT_REFRESH_SECRET` — refresh tokens are
opaque random values, not signed JWTs, so no secret is needed for them (see
ARCHITECTURE.md). An earlier version declared this variable without ever
using it; it's been removed.

## Database migrations

```bash
cd backend
npx prisma migrate deploy   # production: applies pending migrations, no prompts
```

`npx prisma generate` must be run wherever the app is built (it downloads a
platform-specific query-engine binary — make sure your build environment's
network allowlist, if restricted, permits `binaries.prisma.sh`).

## Docker

```bash
# Local dev stack (Postgres + Redis + API)
export JWT_ACCESS_SECRET=$(openssl rand -hex 32)
docker compose up --build
```

The `backend/Dockerfile` is a multi-stage build: dependencies → build
(includes `prisma generate`) → minimal Alpine runtime, non-root user, with
a `HEALTHCHECK` hitting `/health`.

**Production hardening still needed before relying on this Dockerfile /
compose file as-is:**
- `docker-compose.yml` is a **local development** convenience — it runs
  Postgres/Redis as containers with no persistence guarantees beyond the
  named volumes and no backup strategy. Use managed Postgres/Redis in
  production, not these containers.
- No image is currently pushed to a registry by CI (see below) — this repo
  produces a buildable image, not yet an automatically deployed one.

## CI/CD — current state

`.github/workflows/backend-ci.yml` runs on every push/PR touching
`backend/`: install → `prisma generate` → lint → typecheck → test → build
→ (on `main` only) build the Docker image locally to confirm it builds.

**Not yet implemented:**
- Pushing the built image to a registry (GHCR/ECR/etc.) — the step exists
  in the workflow but is commented out pending a registry decision, since
  that requires real credentials/secrets this project doesn't have.
- Automatic deployment to any environment.
- Staging environment configuration.

## Health checks

- `GET /health` — liveness (process is up).
- `GET /ready` — readiness (currently identical to `/health`; extend this to
  check DB/Redis connectivity before considering the instance ready to
  receive traffic behind a load balancer).

## Scaling notes

- The API is stateless (no in-memory session state) and rate limiting is
  Redis-backed specifically so it holds correctly across multiple instances
  — horizontal scaling behind a load balancer should work without further
  changes to the app itself.
- Database connection pooling: Prisma's default pool is per-process: at
  high instance counts, put a connection pooler (PgBouncer, or your managed
  Postgres provider's built-in pooler) in front of Postgres rather than
  letting each instance hold its own large pool.
- No caching layer beyond rate-limit state exists yet (no query result
  caching, no CDN in front of the API).

## Monitoring & observability — current state

- Structured JSON logging via `pino` (`pino-pretty` in development only),
  with `req.headers.authorization`, cookies, and password fields redacted.
- Every request gets a `requestId` (UUID), included in error responses and
  log lines, for correlating a client-reported error with server logs.
- **Not yet implemented**: metrics (Prometheus/StatsD), distributed tracing,
  APM integration, alerting. For a production deployment serving real
  traffic, wire up at minimum: request-latency/error-rate metrics, and
  alerting on 5xx rate and database connection saturation, before launch.

## Secrets management

Current model is a `.env` file (see `.env.example`), which is fine for local
development only. **Before production deployment**, move
`JWT_ACCESS_SECRET`, `DATABASE_URL`, and `REDIS_URL` into a real secrets
manager (AWS Secrets Manager, GCP Secret Manager, Vault, etc.) and inject
them as environment variables at deploy time — do not commit or ship a
`.env` file to production infrastructure.
