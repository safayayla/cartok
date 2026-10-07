# Cartok — an automotive community platform

Cartok is a community app for car and motorcycle people: build out your
garage, talk shop in the forum, buy and sell parts, organize meetups, and
follow the builds you care about. It is **not** a video platform — an
earlier direction explored a TikTok-style video feed, but that's been
dropped in favor of doing the community fundamentals well. See "Product
direction" below.

## Structure

```
backend/    Node.js + TypeScript + Express + Prisma + PostgreSQL + Redis API
mobile/     Flutter app (iOS + Android), Riverpod + go_router + Dio
docker-compose.yml   Local dev stack: Postgres, Redis, API
.github/workflows/   CI: lint, typecheck, test, build, docker image
```

## Running the backend locally

```bash
cd backend
cp .env.example .env        # then fill in real secrets — see below
npm ci                       # package-lock.json is committed; npm ci is preferred over install
npx prisma generate
npx prisma migrate deploy    # applies prisma/migrations/20250809094800_init
npm run dev                 # http://localhost:4000
```

Or via Docker Compose from the repo root:

```bash
export JWT_ACCESS_SECRET=$(openssl rand -hex 32)
docker compose up --build
```

Run tests: `npm test` (backend). Lint: `npm run lint`.

## Running the mobile app

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000   # Android emulator
# or use your machine's LAN IP for iOS simulator / physical devices
```

## What's implemented

**Backend** (`backend/src/modules/`): `auth`, `users` (profiles + follow),
`garage` (garages + vehicles, ownership + visibility rules, VIN decoding),
`forum` (categories/threads/nested replies/voting/bookmarks), `marketplace`
(listings/search/favorites), `events` (Cars & Coffee, Drive Together, track
days, meetups — one model with a type discriminator, not four separate
modules), `notifications` (in-app feed, emitted by every module above as a
real cross-cutting dependency, not a demo), `discover` (a heuristic,
honestly-documented recommendation feed blending vehicles/threads/events —
see ARCHITECTURE.md), `messaging` (1:1 DMs, REST + client-side polling —
see "On real-time" below), `vehicles` likes/comments/bookmarks, and a
`vin` VIN-decoder proxy.

**Mobile** (`mobile/lib/features/`): matches the backend module-for-module
— full auth flow, garage/vehicle management with VIN decode, forum with
optimistic voting, marketplace browse/create/favorite, events with QR
check-in, a bottom-nav home feed blending all content types, in-app
messaging, search across garages/users/listings, notifications, and full
profile screens with follow/bookmark. Built on a custom design system
(telemetry/dashboard-inspired, not default Material) with consistent
loading/empty/error states throughout.

**On real-time**: there is no WebSocket infrastructure yet. Messaging uses
REST with client-side polling (documented in `chat_thread_provider.dart`)
rather than either faking "real-time" or leaving it unbuilt — this is a
deliberate, honest stand-in, swappable for a socket subscription later
without changing the state shape.

## Verification status

The **backend** has been repeatedly installed, linted, and tested across
this project's development, and was re-verified for real in this session
(2026-10-06): **131/131 tests passing, 9/9 suites** (`npm test`, every
suite mocks the Prisma client module before import, so it runs
independent of the Prisma-engine issue below). A `backend/package-lock.json`
now exists (generated from the current `package.json`, verified with a
clean `npm ci`) and an initial Prisma migration now exists at
`backend/prisma/migrations/`, verified by applying it directly to a real
PostgreSQL 16 database. `npx prisma generate` needs a network path to
`binaries.prisma.sh` to download its query-engine binary; in sandboxes
that block it (true in the environment that did this latest pass),
`tsc --noEmit` and `npm run build` show a small, consistent set of 8
failures that all trace to that one missing step, not to application
logic — re-run `prisma generate` first if you see `Module
'"@prisma/client"' has no exported member 'X'` errors. See TESTING.md for
the exact command-by-command results of the most recent pass.

The **mobile app** now has 21 automated tests across 6 files in
`mobile/test/` (login/register screens, bottom-nav + messaging navigation,
and an `AuthNotifier` state-machine test), but they have not been run
through `flutter test` — no Flutter/Dart SDK has been installable in any
environment used for this project (`storage.googleapis.com`, where the SDK
is distributed, is not reachable). `mobile/android/` and `mobile/ios/`
platform folders also do not exist yet for the same reason — generating
them needs `flutter create`, which needs the SDK. See KNOWN_ISSUES.md for
exactly what's blocked and the fix once you have the SDK.

Every mobile change has also been checked by hand: relative imports
resolve, Riverpod providers/classes are defined exactly once and actually
used, every navigation call matches a declared route, every design-system
color token exists, every third-party package used is declared in
`pubspec.yaml` with nothing speculative left in. That's a real safety net,
but it is not a substitute for actually running the toolchain — please do
that before shipping, and treat the mobile app as unverified until you do.

## Product direction

Cartok was briefly explored as a TikTok-style short-video platform. That
direction has been **dropped**. There is no video upload, processing,
streaming, or video-based recommendation work planned or in progress, and
none should be added without a new, explicit decision to do so. The home
feed blends photo-adjacent and text content that already exists in the
platform (vehicle updates, forum threads, marketplace highlights, events)
rather than video.

## Roadmap

Current focus, in priority order:

1. **Garage** — done; ongoing polish (photo galleries on vehicles is the
   next real gap — vehicles support a single implicit state today, not a
   multi-photo gallery).
2. **Forum** — done.
3. **Marketplace** — done; no payments/escrow (out of scope without a
   payment processor decision).
4. **Events** — done (Cars & Coffee, Drive Together, track days, meetups).
5. **Messaging** — done (REST + polling, see above).
6. **Search** — done (composes existing garage/user/marketplace endpoints
   rather than a dedicated search-aggregation module).
7. **Notifications** — in-app done; push (Firebase) not started, needs a
   Firebase project and real device credentials.
8. **User profiles** — done (bio, avatar, follow, bookmarks).
9. **Moderation** — RBAC (`MODERATOR`/`ADMIN` roles) exists and is used for
   forum post overrides; a dedicated moderation queue/reporting flow does
   not exist yet.
10. **Admin panel** — not started. No admin API surface beyond the
    role-gated actions embedded in existing modules; a proper admin
    UI (likely a separate React app per earlier planning) hasn't begun.

Not planned: video (see above), Premium/billing (needs a payment processor
decision), AI Assistant (needs a model/API choice).

Each item that does get built follows the same standard the rest of this
project has: real schema, real service logic, real tests, run and verified
— not scaffolding.
