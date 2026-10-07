# Security

This documents the security decisions actually implemented in Cartok today,
why each one was made, and known trade-offs/gaps. It is not a marketing
document — gaps are listed as gaps.

## Authentication

- **Passwords**: hashed with `argon2id` (memory-hard, resistant to GPU
  cracking), never logged (redacted in the logger config), never returned
  from any endpoint (`sanitizeUser()` strips `passwordHash` before any
  response).
- **Login timing**: a dummy argon2 hash is verified against even when the
  email doesn't exist, so the response shape/timing doesn't reveal account
  existence.
- **Access tokens**: JWT, `HS256` pinned explicitly on both `sign` and
  `verify` (not left to the library default) to close the algorithm-confusion
  attack class, where a token crafted with a different or `none` algorithm
  could otherwise be accepted.
- **Refresh tokens**: opaque random values, never JWTs. Stored server-side
  only as a SHA-256 hash (fast hash is appropriate here — the token itself
  is high-entropy random data, not a guessable password, so slow hashing
  buys nothing and would cost real CPU at scale). Delivered only via an
  `httpOnly`, `Secure`, `SameSite=Strict` cookie — never accessible to
  JavaScript, never sent cross-site.
- **Rotation + reuse detection**: every refresh rotates the token
  (one-time-use). If a token that's already been rotated is presented
  again, every active session for that user is revoked immediately — a
  strong signal of token theft. This rotate-and-revoke check is a single
  atomic conditional `UPDATE ... WHERE revokedAt IS NULL`, not a
  read-then-write, specifically to close a race window where two concurrent
  requests with the same token could otherwise both succeed before either
  write landed. Covered by a dedicated concurrency test
  (`auth.test.ts`) that fires two simultaneous rotation attempts and asserts
  exactly one succeeds.

## Authorization

- **Ownership checks** are enforced in the service layer, not just at the
  route level, for every mutation (garage/vehicle update/delete).
- **Visibility is enforced at two independent levels**: `Garage.isPublic`
  gates the whole garage; `Vehicle.isPublic` separately gates individual
  vehicles within an otherwise-public garage. Both are checked on every read
  path. **This was previously broken** — an earlier version had the
  `isPublic` fields in the schema but never actually checked them anywhere,
  meaning private garages and vehicles (including VINs and odometer
  readings) were fully readable by anyone, unauthenticated. Fixed; see
  CHANGELOG.md and the test cases in `garage.test.ts` that specifically
  assert a 404 (not data) for a private garage viewed by a stranger or an
  anonymous caller.
- **404, not 403, for hidden resources.** Returning 403 for a private
  resource confirms it exists to anyone probing IDs; 404 is indistinguishable
  from "doesn't exist."
- **RBAC**: `requireRole()` middleware for admin/moderator-gated actions
  (forum category creation, post moderation override).

## Input validation

Every request body/query/params is validated and coerced through Zod
schemas before touching a service or the database — this is also the
project's primary SQL-injection/XSS defense (see `middleware/validate.ts`):
nothing unvalidated ever reaches a Prisma call, and Prisma's parameterized
queries prevent SQL injection at the query layer regardless.

## Rate limiting

Redis-backed (survives across multiple API instances behind a load
balancer, not per-process). Two tiers:
- **Auth endpoints**: 10 requests / 15 min, keyed by IP — deliberately IP-based
  even given the NAT caveat below, because at the login/register stage
  there's no token yet to key on, and this is exactly the endpoint where
  broad IP throttling matters most against credential stuffing.
- **General API**: 120 requests / min, keyed by authenticated user when a
  token is present (decoded, not verified — this only picks a rate-limit
  bucket, so an invalid/forged token is harmless here and just lands in its
  own bucket), falling back to IP for anonymous requests. This was changed
  from pure IP-keying specifically because mobile clients very commonly sit
  behind carrier-grade NAT, where IP-only keying would let one user's
  traffic throttle many unrelated users sharing that IP.

## Transport & headers

- `helmet` for standard security headers (CSP, HSTS, X-Content-Type-Options,
  etc.) with `crossOriginResourcePolicy: same-site`.
- CORS is an explicit origin allowlist (`CORS_ORIGINS` env var), never a
  wildcard — required for `credentials: true` to function correctly in
  browsers anyway, but also the right default regardless.
- `trust proxy` is set for correct `req.ip`/secure-cookie behavior behind a
  load balancer/ingress in production.

## CSRF

No separate CSRF token/middleware exists, and none is currently needed:
- The refresh cookie is `SameSite=Strict`, so browsers never attach it to a
  cross-site request in the first place — the primary CSRF vector (a
  malicious page making a credentialed request on the user's behalf) doesn't
  apply.
- Every mutating endpoint requires a `Bearer` access token in an
  `Authorization` header, which a cross-site page cannot attach without
  already having compromised the client (at which point CSRF is not the
  relevant threat model).
- Native mobile HTTP clients aren't subject to browser same-origin policy at
  all, so CSRF in the traditional sense doesn't apply to the current client.

**This will need revisiting if a browser-based web client is added** — at
that point, re-evaluate whether `SameSite=Strict` plus Bearer-token mutations
remains sufficient or whether an explicit CSRF token becomes warranted.

## Error handling

Centralized error handler distinguishes expected (`AppError`, 4xx) from
unexpected (5xx) failures. In production, **any** 5xx response — including
a "known" `AppError` — is masked to a generic message before it reaches the
client; the full detail is always logged server-side. This was tightened
after finding that only the generic unhandled-error path was being masked,
which meant a future `Errors.internal(someSensitiveDetail)` call anywhere in
the codebase would have silently bypassed production message-hiding.

## Known gaps (not yet addressed)

- No email verification flow yet (`emailVerifiedAt` field exists, unused).
- No 2FA/MFA.
- No automated dependency vulnerability scanning in CI yet.
- No WAF/DDoS layer documented — assumed to sit at the infrastructure level
  (e.g. Cloudflare, AWS Shield) in front of this service, not in application code.
- No secrets manager integration documented — `.env` is the current model;
  production deployment should use a real secrets manager (see
  DEPLOYMENT.md) rather than plain environment files.

## Reporting a vulnerability

This is a demonstration/development-phase project without a public bug
bounty program at this time. If this were a live production service, this
section would list a security contact email and disclosure policy.
