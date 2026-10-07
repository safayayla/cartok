# Cartok Architecture

This document describes the architecture as it actually exists today, not
an aspirational end-state. Where something is planned but not built, it's
labeled "Not yet implemented." Where something was once planned and has
since been dropped (video), it's noted as dropped, not silently removed —
so nobody re-proposes it without knowing it was a deliberate decision.

## Product direction note

Cartok was briefly explored as a TikTok-style short-video platform. That
direction has been **dropped** in favor of an automotive community app:
garage, forum, marketplace, events, messaging. There is no video upload,
transcoding, streaming, or video-based recommendation code anywhere in this
codebase, and none should be added without a new, explicit product decision
to revisit it.

## System overview

```
┌─────────────────┐         ┌──────────────────┐         ┌──────────────┐
│  Flutter mobile  │◄──────►│   Express API     │◄──────►│  PostgreSQL   │
│  (iOS/Android)   │  HTTPS │   (Node/TS)       │         │  (Prisma)     │
└─────────────────┘         └──────────────────┘         └──────────────┘
                                     │
                                     ▼
                             ┌──────────────┐
                             │    Redis      │  (rate limiting)
                             └──────────────┘
                                     │
                                     ▼
                             ┌──────────────┐
                             │ NHTSA vPIC API │ (VIN decoding, external)
                             └──────────────┘
```

One backend service (a monolith), not microservices. At this stage that's
the right call: every domain shares one Postgres instance and one
deployment unit, simpler to operate than a distributed system with no
traffic yet to justify the split.

## Backend module layout

```
backend/src/
  app.ts              Express app assembly: middleware, routers, error handling
  server.ts           Process entrypoint: startup, graceful shutdown
  config/             Env validation, Prisma client, Redis client, logger
  middleware/         auth (JWT+RBAC), validate (Zod), rateLimit, errors
  modules/
    auth/              register, login, refresh rotation, logout
    users/             profile read/update, follow/unfollow, user search
    garage/            garage CRUD, ownership, visibility, follow, browse
    vehicles/          vehicle CRUD, likes, comments, bookmarks, VIN enrichment
    vin/               standalone VIN decode endpoint
    forum/              categories, threads, posts, voting, bookmarks
    marketplace/        listings, search/filter, favorites
    events/             Cars & Coffee / Drive Together / track days / meetups
                         (one model with a type discriminator, not 4 modules),
                         RSVP with race-safe capacity enforcement, QR check-in
    notifications/      in-app feed, emitted by every module above
    discover/            heuristic recommendation feed (see below)
    messaging/           1:1 DM conversations, REST (see "Real-time" below)
  utils/              VIN decoder (NHTSA integration)
  __tests__/          integration tests, one file per module
```

Each module follows the same shape: `*.schemas.ts` (Zod validation),
`*.service.ts` (business logic + Prisma calls), `*.controller.ts` (HTTP
glue), `*.routes.ts` (Express Router). A new module should be predictable
to navigate without reading its code first.

## Data model

Postgres via Prisma. Design principles applied throughout:

- **Visibility is enforced at two levels independently**: a `Garage.isPublic`
  flag gates the whole garage, and a `Vehicle.isPublic` flag gates individual
  vehicles within an otherwise-public garage. Both are checked on every read
  path. This was previously a real bug (private garages/vehicles were fully
  exposed) — fixed early, and the lesson is now baked into every new
  visibility-sensitive endpoint added since (garage browse, event check-in
  codes, etc.), each with a comment citing the original bug as the reason.
- **Soft delete over hard delete** for user-generated content (forum posts,
  vehicle comments): `isDeleted` is set, content is preserved for
  moderation, and masking to `"[deleted]"` happens only at the API read
  layer.
- **Denormalized counters where reads are hot**: `ForumPost.score` is
  maintained via atomic `increment`/`decrement` inside a transaction
  alongside the vote row, rather than summing vote rows on every read.
- **Race-safe capacity enforcement**: Event RSVP capacity checks use an
  explicit `SELECT ... FOR UPDATE` row lock, not just a transaction wrapper
  — under Postgres's default `READ COMMITTED` isolation, a transaction
  alone does not stop two concurrent reads from both seeing room before
  either commits.
- **Cursor-based pagination** (`cursor` + `limit`, capped at 50) on every
  list endpoint that can grow unbounded.

## Auth model

- **Access tokens**: short-lived (15 min default) JWTs, `HS256` explicitly
  pinned on both sign and verify to prevent algorithm-confusion attacks.
- **Refresh tokens**: opaque random values (not JWTs), stored server-side
  only as a SHA-256 hash, delivered via an `httpOnly`, `Secure`,
  `SameSite=Strict` cookie. Rotated on every use with reuse-detection via a
  single atomic conditional `UPDATE` (not read-then-write) — closes a real
  TOCTOU race where concurrent rotation attempts on the same token could
  otherwise both succeed.
- **RBAC**: `USER`, `MODERATOR`, `ADMIN`. Currently gates forum category
  creation and post moderation; the admin panel and a proper moderation
  queue (see roadmap) will extend this, not replace it.

## The Discover feed (recommendation engine)

`discover.service.ts` is a real, working recommendation feed — an honest
heuristic one, not a claimed ML model. It blends three content types
(public vehicles, forum threads, upcoming events) with independent scoring
(engagement + recency + "do you follow the source") and no video content,
because none exists. Documented limitations, in the code itself:
per-type scores aren't normalized onto a shared scale before blending, and
candidates are scored live in application code rather than precomputed —
both fine at today's scale, both real future work if traffic grows.

## Real-time (or the honest lack of it)

There is no WebSocket/push infrastructure. Messaging (`messaging.service.ts`)
is plain REST — list conversations, list messages, send. The Flutter client
polls every 4 seconds while a conversation thread is open
(`chat_thread_provider.dart`), with a comment explaining exactly why and
noting the state shape is designed to swap to a socket subscription later
without a rewrite. This is a deliberate choice to ship something that
actually works today over a fake "real-time" claim or leaving the feature
unbuilt.

## Mobile app architecture

Flutter + Riverpod (state) + go_router (navigation, `StatefulShellRoute`
bottom-nav) + Dio (networking).

```
mobile/lib/
  main.dart           One-time async init (cookie jar) before runApp()
  app/                Root widget, go_router config, bottom-nav shell
  core/
    theme/            Design system: colors, typography, ThemeData
    network/          Dio client with auto-refresh-on-401 interceptor
    storage/           Secure token storage
    widgets/           Shared widgets: gauge-arc (signature element),
                        empty/error states
    utils/              Share helper (native OS share sheet)
  features/
    auth/, garage/, forum/, marketplace/, events/, notifications/,
    profile/, search/, discover/, messaging/
      Each follows: models/, repository/, providers/, screens/
```

Key architectural decisions:
- **One `ApiClient` instance for the app's lifetime**, constructed once in
  `main()` after its cookie jar resolves — not reactively rebuilt. An
  earlier version watched the cookie-jar provider reactively, which caused
  the entire client→repository→auth-notifier chain to rebuild and
  session-restore to fire twice on every cold start. Fixed; documented in
  the provider file so it isn't reintroduced.
- **Optimistic UI** as the default pattern for anything vote/follow/
  bookmark/like-shaped: the button and count update instantly, and only
  roll back if the network call actually fails. Used consistently across
  forum voting, profile follow, garage follow, and vehicle likes/bookmarks.
- **Design system over ad-hoc styling**: colors/typography/the gauge-arc
  motif are centralized and reused, never redefined per screen.

## What's NOT implemented (and why)

- **Video** (upload, transcoding, streaming, video-based recommendations):
  dropped as a product direction — see the note at the top of this doc.
- **Push notifications** (Firebase): needs a real Firebase project and
  device credentials, not just code.
- **Premium/billing**: needs a payment processor decision (Stripe or
  similar) before any code is worth writing.
- **AI Assistant**: needs a model/API choice and prompt design.
- **Admin panel**: no dedicated admin UI exists yet; RBAC exists and is
  used inline within existing modules (forum moderation), but a proper
  moderation queue and admin dashboard have not been built.
- **OpenAPI/API documentation**: not written.
- **Monitoring/observability**: structured logs only (pino, redacted
  sensitive fields, per-request IDs); no metrics/tracing/alerting wired up.
- **CI does not push Docker images to a registry**: the step exists in the
  workflow but is commented out pending a registry decision.

See `README.md` for the current priority order.
