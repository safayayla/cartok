# Testing

## What's actually true right now

This document distinguishes three different things, because conflating
them is how projects end up shipping broken software with a green
checkmark next to it:

1. **Tests that exist** (written, real assertions, in the repo)
2. **Tests that have been executed and passed** (and when/where)
3. **Static checks performed without executing anything** (grep-based
   audits, manual code reading, import-graph verification)

## Backend

**Framework**: Vitest + Supertest, with an in-memory mock of the Prisma
client per test file (no real Postgres/Redis required to run the suite).

**Test files** (`backend/src/__tests__/`, one per module):
`auth.test.ts`, `users.test.ts`, `garage.test.ts` (covers both Garage and
Vehicles, including likes/comments/bookmarks), `forum.test.ts`,
`marketplace.test.ts`, `events.test.ts`, `notifications.test.ts`,
`discover.test.ts`, `messaging.test.ts`.

**Last actually-executed result** (this session, 2026-10-06, re-verified
after a session restart — every command below was re-run from a clean
`node_modules`/`dist`, not copied from an earlier report):

| Command | Result |
|---|---|
| `npm ci` (with freshly generated `package-lock.json`) | ✅ PASS |
| `npm run lint` | ✅ PASS, 0 errors |
| `npx prisma generate` | ❌ BLOCKED — `binaries.prisma.sh` returns `403 Forbidden` from this environment's egress proxy (confirmed by direct `curl` and by the real `prisma generate` error text, including with `PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1`) |
| `npx tsc --noEmit` | ❌ 8 errors, all tracing to the single root cause above (see below) |
| `npm test` (vitest) | ✅ **131/131 PASS, 9/9 suites** — every suite replaces `../config/prisma` with `vi.mock(...)` before import, so the suite never touches the real (ungenerated) `@prisma/client` and is unaffected by the blocked engine download |
| `npm run build` | ❌ exits 2 — `tsc` reports the same 8 errors as `--noEmit`, but still emits JS to `dist/` (the project doesn't set `noEmitOnError`), so `dist/server.js` exists despite the non-zero exit |
| `npx prisma migrate deploy` | ❌ BLOCKED, same engine-binary restriction. The migration SQL was instead verified directly: applied with `psql` against a real, freshly-created PostgreSQL 16 database — all tables/indexes/FKs created, 0 errors |
| `docker build` (backend Dockerfile) | ❌ BLOCKED — Docker daemon starts and runs fine, but `registry-1.docker.io` (the `node:20-alpine` base image) returns `403 Forbidden`/`failed to resolve source metadata` from the same proxy, so the build can't even reach the first `FROM` line |

**Correction to an earlier draft of this document**: a previous pass
through this session reported `npm test` as 0/0 ran with a
`Cannot find module '.prisma/client/default'` error. That was not
accurate for this codebase — re-run and inspected directly, all 9 test
files mock the Prisma client at the module level
(`vi.mock("../config/prisma", ...)`), so they don't import the generated
client at all and all 131 tests pass regardless of whether `prisma
generate` has run. The 8 `tsc`/`build` errors are real and still blocked
on the same root cause; only the test-suite claim was wrong, and this
document has been corrected rather than left standing.

Re-run the full sequence yourself in an environment with normal internet
access to confirm `prisma generate`/`migrate deploy`/`docker build` too:

```bash
cd backend
npm ci
npx prisma generate    # needs network access to binaries.prisma.sh
npx prisma migrate deploy
npm run lint
npx tsc --noEmit
npm test
npm run build
```

**The 8 `tsc`/`build` errors, exactly as produced**, so you can confirm
they disappear once `prisma generate` succeeds on your machine:

```
src/middleware/auth.ts(5,15): error TS2305: Module '"@prisma/client"' has no exported member 'Role'.
src/middleware/errors.ts(56,14): error TS2339: Property 'PrismaClientKnownRequestError' does not exist on type 'typeof Prisma'.
src/middleware/errors.ts(56,69): error TS2339: Property 'PrismaClientKnownRequestError' does not exist on type 'typeof Prisma'.
src/middleware/errors.ts(57,9): error TS18046: 'err' is of type 'unknown'.
src/middleware/errors.ts(62,9): error TS18046: 'err' is of type 'unknown'.
src/modules/auth/auth.service.ts(8,15): error TS2305: Module '"@prisma/client"' has no exported member 'Role'.
src/modules/auth/auth.service.ts(8,21): error TS2305: Module '"@prisma/client"' has no exported member 'User'.
src/modules/notifications/notifications.service.ts(2,15): error TS2305: Module '"@prisma/client"' has no exported member 'NotificationType'.
```

The two `TS18046` errors are themselves downstream of the
`PrismaClientKnownRequestError` ones: once that property can't be found
on the ungenerated `Prisma` namespace, `err instanceof
Prisma.PrismaClientKnownRequestError` can't narrow `err`'s type, so it
stays `unknown`. All 8 are one bug, not eight — and none of them affect
the test suite, since every test file mocks this module away entirely.

**What the backend suite actually covers**, because "131 tests" is
meaningless without knowing what they assert: ownership/ownership-bypass
checks on every mutating endpoint, visibility rules for private
garages/vehicles (this was a real, fixed security bug — see SECURITY.md),
a genuine concurrency test that fires two simultaneous refresh-token
rotation attempts and asserts exactly one succeeds, forum vote-score math
(new vote / flipped vote / resubmit / removal, not just "score went up
once"), event RSVP capacity enforcement under a row lock, and the
check-in-code visibility fix (only the host can see it, not the public
list). These aren't smoke tests; they're the specific correctness
properties that were actually at risk.

**What it does NOT cover**: load/performance testing, real-database
integration testing (the mock Prisma client can diverge from real Postgres
behavior — every mock was hand-written per test file, and mock bugs have
been found and fixed multiple times during development, which is itself a
reason to eventually add a real-database test tier, not proof the mocks
are currently wrong).

## Mobile (Flutter)

**21 automated tests now exist across 6 files** (`mobile/test/`):
- `features/auth/login_screen_test.dart` — 4 tests: form renders (email,
  password, submit button), password visibility toggle, empty-field
  validation, invalid-email validation
- `features/auth/register_screen_test.dart` — 5 tests: one per validated
  field (display name, username format, email format, password strength)
  plus a fully-valid-form pass with no errors shown
- `providers/auth_notifier_test.dart` — 5 tests against the real
  `AuthNotifier` state machine with a mocked `AuthRepository`: session
  restore (success and failure), `login()` success/failure state
  transitions, `logout()` clearing state — the "meaningful
  provider/repository test" called for by the brief
- `navigation/bottom_nav_navigation_test.dart` — 6 tests driving the REAL
  `appRouterProvider`/`StatefulShellRoute` (not a reimplemented router):
  lands on Home, taps to Garage/Forum/Marketplace/Events, and confirms
  each tab keeps its own stack
- `navigation/messaging_navigation_test.dart` — 1 test: the Home feed's
  mail icon pushes the real `ConversationListScreen`
- `helpers/mock_repositories.dart` — shared `mocktail` doubles for every
  repository these tests touch, so no test makes a real network call

**These tests have NOT been executed.** No Flutter/Dart SDK is installed
in this environment, and none can be installed: `pub.dev` and
`storage.googleapis.com` (where the Flutter SDK itself is distributed)
both return `403 Forbidden` from this environment's egress proxy,
confirmed by direct `curl`. A `git clone` of the `flutter/flutter` GitHub
repo does work (GitHub isn't blocked), but the `flutter` tool still needs
to download its prebuilt engine/Dart SDK from the blocked
`storage.googleapis.com` host on first run, so cloning the repo doesn't
unblock anything.

The tests were written by reading the actual screen widgets, provider
definitions, and repository method signatures in this repo — not
boilerplate. They have been manually reviewed for correctness (matching
mocktail stub signatures to real call sites, matching widget text to
actual screen source) but **that is not the same as having run them**.
Run them yourself before trusting they pass:

```bash
cd mobile
flutter pub get
flutter test
```

If any fail, that is useful, real signal about either the test or the
app — not a sign this document lied about their status; it explicitly
does not claim they passed.

**What has substituted for it, every time mobile code changed**: a
static-verification routine, run by hand, not by a compiler:
- Every relative import (`../../../core/...`) resolves to a real file on
  disk (scripted check, not eyeballing).
- Every Riverpod provider is defined exactly once and is actually
  referenced somewhere (catches both duplicates and dead providers).
- Every `context.push()`/`context.go()` navigation call's target string
  matches an actual declared `GoRoute` path, checked by extracting and
  pairing them, not just comparing counts.
- Every color token referenced (`CartokColors.x`) actually exists in the
  design system.
- Every imported third-party package is declared in `pubspec.yaml`, and
  nothing is declared-but-unused.
- Third-party API usage (go_router's `StatefulShellRoute`, the `Badge`
  widget's constructor, `share_plus`'s current API) has been checked
  against current documentation via web search when there was real doubt,
  rather than assumed from training data.

This catches an entire, real class of bugs — it has caught actual ones
during development (stale route paths after a refactor, a `copyWith`
pattern that couldn't represent clearing a field to null, a package
that was declared-unused then silently required by new code). **It does
not catch**: type errors the Dart analyzer would catch, widget-tree
runtime exceptions, logic bugs in code that imports and references
correctly but computes the wrong thing, or anything about actual
rendering/layout/performance on a device or simulator.

**Before shipping**, at minimum:
```bash
cd mobile
flutter pub get
flutter analyze
flutter test              # 21 tests now exist; see above - not yet run here
```
And manual QA on a real device/simulator for every flow in
BETA_CHECKLIST.md — static checks are not a substitute for actually
running the app.

## Environment limitations encountered during this project

- **Prisma engine binary**: `prisma generate` and `prisma migrate deploy`
  need network access to `binaries.prisma.sh` to download a
  platform-specific query/schema-engine binary. This session's egress
  proxy returns `403 Forbidden` for that host specifically (confirmed by
  direct `curl`, and by the actual `prisma generate`/`migrate` error
  text, three separate times including with the checksum-ignore escape
  hatch). This makes `tsc --noEmit` and `npm run build` show a small,
  consistent set of "Module '\"@prisma/client\"' has no exported member
  'X'" errors, and makes every `npm test` suite fail at import — these
  all trace entirely to the missing generate step, not to application
  logic. Once `prisma generate` succeeds (e.g. in CI, or any environment
  with normal internet access), they resolve.
- **Docker Hub**: `registry-1.docker.io` is blocked the same way, so
  `docker build` cannot pull the `node:20-alpine` base image here even
  though the Docker daemon itself runs fine.
- **Flutter SDK**: no environment used across this project's development
  has had the Flutter SDK installed, and no path existed to install one.
  This session specifically confirmed: `pub.dev` and
  `storage.googleapis.com` (where Flutter's SDK and engine binaries are
  distributed) both return `403 Forbidden`. A `git clone` of
  `flutter/flutter` from GitHub does succeed (GitHub isn't blocked), but
  the `flutter` tool still needs `storage.googleapis.com` to bootstrap its
  bundled Dart SDK on first run, so that doesn't unblock anything either.
- **This session, npm/Postgres/Docker specifically**: unlike some earlier
  sessions in this project's history, `registry.npmjs.org` worked (`npm
  ci`/`npm install` succeeded), a local PostgreSQL 16 server was available
  and used to verify the hand-written initial migration directly, and the
  Docker daemon itself started and ran (just blocked on the Docker Hub
  base-image pull). Network restrictions are per-host, not a single
  on/off switch — each host was checked individually rather than assumed.

## Recommended test additions before a real beta

In priority order, given what's actually shipped:
1. **Flutter widget tests** for the optimistic-update flows (forum vote,
   garage/profile follow, vehicle like/bookmark) — these have the highest
   bug-surface-per-line of any pattern in the app, since each one needs to
   get the rollback-on-failure path right, not just the happy path.
2. **A real-Postgres integration test tier** for the backend, run in CI
   against an actual `postgres:16-alpine` container (the CI workflow
   already spins one up for this purpose — see `.github/workflows/`) —
   to catch any place the hand-written mocks diverge from real Prisma/
   Postgres behavior.
3. **E2E tests** (Maestro, Patrol, or similar) for the core funnels:
   register → create garage → add vehicle; browse forum → reply → vote;
   create listing → favorite → message seller.
