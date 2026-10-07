# Beta Checklist

This is a checklist to actually *do*, not a claim that it's done. Items are
checked only where they were actually executed and verified in this
environment, with how, see TESTING.md for the full detail and exact error
output.

## Release blockers from the "FIX ACTUAL RELEASE BLOCKERS" pass

- [x] `backend/package-lock.json` generated via `npm install`, verified
      with a real `npm ci` in a clean `node_modules`
- [x] `backend/prisma/migrations/20250809094800_init/` created from the
      current `schema.prisma`, verified by applying it with `psql` directly
      to a fresh PostgreSQL 16 database (25 tables, 0 errors) — NOT via
      `prisma migrate deploy`, which could not run (see below)
- [ ] `npx prisma generate` / `npx prisma migrate deploy` — **blocked**:
      `binaries.prisma.sh` returns `403 Forbidden` from this environment's
      egress proxy (confirmed by direct `curl`, not assumed)
- [x] `mobile/test/` populated with 6 real test files / 21 tests — written
      and reviewed against the actual app source, but **not executed**: no
      Flutter/Dart SDK is installable here (`pub.dev` and
      `storage.googleapis.com` both return `403` from the proxy)
- [ ] `mobile/android/` / `mobile/ios/` platform folders — **blocked**, same
      reason; `flutter create` cannot run without the SDK. Not fabricated
      by hand, per the brief's instruction not to fake this.
- [x] Branding sweep — zero live GearHub/gearhub/GH_/gh_ references found
- [x] `.github/workflows/backend-ci.yml` consistency — verified by
      inspection against `package.json` scripts, matches
- [x] Docker `npm ci` left untouched (not swapped for `npm install`);
      daemon started and a real `docker build` attempted — **blocked** at
      the base-image pull (`registry-1.docker.io` also returns `403`)

## Before anything else: verify the toolchain actually works

- [x] `cd backend && npm ci` succeeds (clean install, verified twice)
- [ ] `npx prisma generate` succeeds — **blocked**, see above
- [ ] `npx prisma migrate deploy` succeeds against a real Postgres instance
      — blocked (same engine-binary restriction); the migration SQL itself
      was verified directly against Postgres 16 with `psql` instead
- [x] `npm run lint` — zero errors (actually run)
- [ ] `npx tsc --noEmit` — **8 errors**, actually run, all 8 trace to the
      same single root cause: `@prisma/client` has no generated types
      because `prisma generate` never ran. Not a real code defect — see
      TESTING.md for the exact error list and reasoning
- [x] `npm test` — **131/131 tests pass, 9/9 suites**, actually run.
      Unaffected by the `tsc` issue above because every suite mocks the
      Prisma client module before import (`vi.mock("../config/prisma")`),
      so it never touches the ungenerated real client
- [ ] `cd mobile && flutter pub get` — cannot run, no Flutter SDK installed
      or installable in this environment
- [ ] `flutter analyze` — cannot run, same reason
- [x] `flutter test` — 21 tests now exist across 6 files (previously: zero
      test files existed). Cannot be executed here for the same SDK reason;
      not claimed to pass, only written and reviewed

## Backend: run it for real

- [ ] `docker compose up --build` from the repo root starts Postgres,
      Redis, and the API cleanly
- [ ] `GET /health` and `GET /ready` return 200
- [ ] Manually exercise: register → login → create garage → add vehicle →
      like it from a second account → comment → verify notification
      arrived for the first account
- [ ] Manually exercise: create forum thread → reply from a second
      account → upvote → verify score and notification
- [ ] Manually exercise: create marketplace listing → favorite from a
      second account → message the seller → verify conversation appears
      for both accounts
- [ ] Manually exercise: create a Cars & Coffee event with capacity 1 →
      RSVP from account A → RSVP from account B → confirm B is rejected
      with a capacity error, not a silent overbook

## Mobile: run it for real

Nothing below has been done in any environment this project has used.
None of it should be assumed to work until it's actually run.

- [ ] App builds and launches on an Android emulator
- [ ] App builds and launches on an iOS simulator
- [ ] Cold start: splash → session restore → lands on Home feed (or
      login, if no session) — confirm no double-flash/flicker (this was a
      real, fixed bug earlier in development; confirm it stays fixed)
- [ ] Every bottom-nav tab (Home, Garage, Forum, Market, Alerts, Events)
      loads without a crash
- [ ] Pull-to-refresh works on every list screen
- [ ] Infinite scroll works on forum threads, marketplace browse,
      notifications
- [ ] Every optimistic-update flow (forum vote, follow, like, bookmark)
      updates instantly and — this is the part that's easy to get wrong —
      actually rolls back correctly if you turn on airplane mode mid-tap
- [ ] Every list screen's empty state actually renders (easiest way to
      check: a fresh account with no data yet)
- [ ] Every list screen's error state actually renders (easiest way to
      check: airplane mode)
- [ ] Deep interaction: profile → message button → send a message →
      appears in conversation list for both accounts
- [ ] Logout actually clears the session (relaunch the app after logging
      out; confirm it lands on login, not a stale authenticated state)

## Before submitting to Google Play (internal/closed testing track)

- [ ] Android platform folder still does not exist — `flutter create .
      --platforms=android` needs to be run on a machine with the Flutter
      SDK installed (this environment cannot install one; see
      KNOWN_ISSUES.md)
- [ ] App display name, package ID (`applicationId`), and app icon set to
      final Cartok branding
- [ ] Signing key generated and kept somewhere that isn't lost (losing it
      means you can never update the app under the same listing again)
- [ ] `API_BASE_URL` points at a real deployed backend, not
      `10.0.2.2`/localhost
- [ ] Privacy policy URL ready (required by Play Console) — this app
      collects email, profile data, location-adjacent event data, and
      messages; the privacy policy needs to actually describe that
- [ ] Play Console data-safety form filled out accurately against what
      the backend actually collects (see SECURITY.md)

## Before submitting to the Apple App Store (TestFlight)

- [ ] iOS platform folder still does not exist — same prerequisite as
      Android, `flutter create . --platforms=ios` on a machine with the SDK
- [ ] Apple Developer account enrolled, App ID + provisioning profile
      created
- [ ] App display name, bundle ID, and app icon set to final Cartok
      branding
- [ ] `API_BASE_URL` points at a real deployed backend
- [ ] App Store privacy "nutrition label" filled out accurately
- [ ] TestFlight build uploaded and processed before inviting beta testers

## Infrastructure

- [ ] Real Postgres and Redis provisioned (managed services recommended —
      `docker-compose.yml` is explicitly a local-dev convenience, not a
      production deployment target, see DEPLOYMENT.md)
- [ ] `JWT_ACCESS_SECRET` generated fresh for production
      (`openssl rand -hex 32`) and stored in a real secrets manager, not a
      `.env` file
- [ ] `CORS_ORIGINS` set to the actual production origin(s), never a
      wildcard
- [ ] Backend deployed somewhere with the health-check endpoints wired to
      the platform's actual health-check mechanism
