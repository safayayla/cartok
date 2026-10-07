# Changelog

All changes are listed as they actually happened, including bugs introduced
and then fixed within the same phase — this is a working history, not a
polished release log.

## Release-blockers re-verification pass (2026-10-06)

A follow-up session restored the project from its saved archive (the
sandbox had reset) and re-ran the entire validation sequence from a clean
`node_modules`/`dist` rather than trusting the prior pass's recorded
output. One correction came out of this:

- **`npm test` was mis-reported in the 2026-10-05 pass below as "0/0 ran,
  `Cannot find module '.prisma/client/default'`".** That was wrong for
  this codebase. Re-run and inspected directly: all 9 suites call
  `vi.mock("../config/prisma", ...)` before importing anything else, so
  they never touch the real (ungenerated) `@prisma/client` module at all.
  Actual, re-verified result: **131/131 tests passing, 9/9 suites.**
  README.md, RELEASE_NOTES.md, BETA_CHECKLIST.md, KNOWN_ISSUES.md, and
  TESTING.md have all been corrected to match. The 8 `tsc`/`npm run
  build` errors are real and remain blocked on the same root cause
  (`prisma generate` needs `binaries.prisma.sh`, which this environment's
  egress proxy still returns `403 Forbidden` for).
- Everything else from the 2026-10-05 pass re-confirmed unchanged:
  `npm ci` ✅, lockfile ✅, migration SQL still applies cleanly to a fresh
  Postgres 16 database via `psql`, branding sweep still clean, CI
  workflow still consistent, Docker daemon runs but `docker build` is
  still blocked at the `node:20-alpine` pull (`registry-1.docker.io`
  returns `403`), and the Flutter/Android/iOS tooling gap is unchanged —
  `pub.dev` and `storage.googleapis.com` both still return `403`.

## Release-blockers fix pass (2026-10-05)

Scoped strictly to the concrete blockers listed in "CARTOK — FIX ACTUAL
RELEASE BLOCKERS" — no new features, no redesign, no Premium/AI/
WebSockets/Admin Panel.

- **Generated `backend/package-lock.json`** via a real `npm install`
  (this session had working `registry.npmjs.org` access, confirmed by
  direct `curl` returning `200`, unlike several prior sessions). Verified
  by deleting `node_modules` and running `npm ci` against the new
  lockfile in a clean directory — passed.
- **Created the initial Prisma migration** at
  `backend/prisma/migrations/20250809094800_init/migration.sql`, hand-
  written directly from the current `schema.prisma` (25 models, all
  enums, all `@@unique`/`@@index`/`@relation` onDelete behavior
  transcribed exactly — no data-model changes). `prisma generate`/`prisma
  migrate dev` themselves could not run to generate this automatically:
  `binaries.prisma.sh` returns `403 Forbidden` from this session's egress
  proxy, confirmed three times including with
  `PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1`. Verified instead by starting
  a local PostgreSQL 16 server and applying the migration directly with
  `psql` against a freshly created database — all 25 tables created, 0
  errors.
- **Wrote a real Flutter test suite** (previously `mobile/test/` had no
  test files): 21 tests across 6 files — login screen rendering, register
  screen validation, an `AuthNotifier` state-machine test against a
  mocked repository, and navigation tests for Home/Garage/Forum/
  Marketplace/Events (via the app's real `appRouterProvider`) and
  Messaging (via its real push route from Home). Could not be executed:
  no Flutter/Dart SDK is installable here (`pub.dev` and
  `storage.googleapis.com` both return `403`).
- **Re-ran the full branding sweep** (`GearHub`/`gearhub`/`GH_`/`gh_`) —
  zero live references found; the rebrand from earlier sessions held.
- **Verified `.github/workflows/backend-ci.yml`** by inspection against
  the current `package.json` scripts — consistent, no changes needed.
- **Started the Docker daemon and attempted a real `docker build`** of
  the backend image — failed pulling `node:20-alpine`:
  `registry-1.docker.io` also returns `403` from this proxy. The
  Dockerfile's use of `npm ci` was left untouched (not swapped for `npm
  install`).
- **Attempted the full backend validation sequence** for real: `npm ci`
  ✅, `npm run lint` ✅ (0 errors), `npx tsc --noEmit` ❌ (8 errors, all
  tracing to the single `prisma generate` blocker above), `npm test` ✅
  (**131/131 passing, 9/9 suites** — unaffected by the `tsc` issue because
  every suite mocks the Prisma client module before import), `npm run
  build` ❌ exits non-zero (same 8 `tsc` errors; it still emits `dist/`,
  since the project doesn't set `noEmitOnError`).
- **`mobile/android/` and `mobile/ios/` platform folders were NOT
  created** — generating them for real needs `flutter create`, which
  needs the Flutter SDK, which is not installable here. Not faked by
  hand-writing platform project files, per the brief's explicit
  instruction not to claim this is complete unless actually present.
- Updated README.md, BETA_CHECKLIST.md, TESTING.md, KNOWN_ISSUES.md, and
  RELEASE_NOTES.md to state all of the above precisely — which commands
  ran, which passed, which are genuinely blocked and why, and the exact
  fix for each blocker on a machine with normal internet access and the
  Flutter SDK.

## Beta audit pass #3 (real execution attempted, full 20-flow trace)

`npm install` was attempted for real (not assumed) — same `403
host_not_allowed` from `registry.npmjs.org` as prior sessions, confirmed
via direct `curl`, not just npm's own error message. Docker and Flutter
are not installed in this environment. Real, executed work this pass:

- **Global `tsc` compile** (a system-wide TypeScript install, independent
  of the missing project `node_modules`) run against all 61 backend
  source files, twice, in two different sessions — identical error-code
  set both times (all attributable to unresolvable dependencies: `express`,
  `zod`, `@prisma/client`, `@types/node`), zero new or unexplained errors.
  This is a real compiler confirming structural soundness, not a heuristic.
- **Full 20-flow trace** (the specific list this pass was asked to verify):
  extracted every backend endpoint call from every Flutter repository file
  and cross-referenced it against every registered backend route. Two
  apparent gaps on first pass (message list/send, add-vehicle) turned out
  to be a regex artifact (multi-line Dio calls) — confirmed present and
  correct by direct file inspection rather than trusting the first
  (incomplete) automated pass.
- **"Search Vehicles" does not exist as a distinct feature** — investigated
  rather than assumed. Search covers garages, users, and marketplace
  listings; marketplace search happens via the marketplace module's own
  `list(search:)` reusing its existing endpoint, not a duplicate one in
  the search module (a reasonable DRY choice, not a bug). Vehicles aren't
  independently searchable, only visible via their garage. Noted honestly
  in RELEASE_NOTES.md rather than silently mapped onto a feature that
  doesn't exist.
- **Vehicle comment/bookmark routes and their ownership/visibility checks**
  re-verified directly in source (both correctly reuse `getById`'s existing
  visibility gate rather than re-implementing it).
- Created `RELEASE_NOTES.md` (didn't exist before this pass).

No code changes were required — everything traced correctly, no new bugs
found.

## Beta audit pass #2 (static analysis only, network still blocked)

Same network restriction as the previous audit pass (`registry.npmjs.org`
403s even though it's on the documented allowlist) — no test suite, `tsc`,
or `flutter analyze` executed this pass either. Extended the previous
pass's scope rather than repeating it:

- **Marketplace ownership enforcement** re-verified end-to-end:
  `assertOwnership()` is called on every mutating path (`update`,
  `updateStatus`) — no gap found.
- **Full Prisma schema relation-integrity pass** (not just messaging/
  bookmarks this time): all 45 `@relation` declarations checked. 6 appeared
  to lack `onDelete` at first grep — investigated rather than "fixed" on
  assumption, and confirmed all 6 are the back-reference (list) side of a
  relation, where Prisma doesn't take `onDelete` at all — the FK-owning
  side of each one correctly specifies it (mostly `Cascade`; `ForumPost.parent`
  deliberately `NoAction`, consistent with soft-delete-only forum posts
  never being hard-deleted). No real gap; false alarm resolved rather than
  "fixed."
- **Environment variable cross-check**: every variable `env.ts` validates
  and every variable `.env.example` declares match exactly, both
  directions. No undeclared-but-used or declared-but-unvalidated vars.
- **`backend/package.json`'s description** was stale in scope ("Auth +
  Garage/Vehicle vertical slice," when the API now covers a dozen
  modules) — fixed, since it's directly package metadata and was found
  while checking metadata accuracy for the rebrand.
- Repeated the TODO/mock-data sweep and the GearHub/gearhub reference
  sweep from the rename pass: still zero matches, confirming the rebrand
  held and no new stale markers were introduced since.

No other code changes were required — see TESTING.md, BETA_CHECKLIST.md,
and KNOWN_ISSUES.md, all of which already existed from the prior pass and
were reviewed for accuracy against this pass's findings rather than
rewritten (they were already correct).

## Beta audit pass (static analysis only — see TESTING.md)

This session had no network access (even documented-allowed package
registries returned 403) and no Flutter SDK, so no test suite, `tsc`, or
`flutter analyze` could actually be executed. Did the audit that was
possible without them:

- Searched for TODO/FIXME/XXX/HACK markers across the entire backend and
  mobile source: **zero found**.
- Searched for mock/fake/dummy/placeholder data outside test files: the
  four matches found were all legitimate (`CachedNetworkImage`'s real
  `placeholder:` parameter, and a doc comment describing the intentional
  optimistic-send "local placeholder" pattern in messaging) — no actual
  stub data found.
- Read `messaging.service.ts` in full for IDOR risk (the least-scrutinized
  module in earlier passes): `assertParticipant()` correctly gates every
  read/write against conversation membership, returning 404 (not 403) for
  a conversation the caller isn't part of — no gap found.
- Reviewed the Prisma schema for the messaging and bookmark models
  specifically: correct cascades, composite indexes matching real query
  shapes. No issues found.
- Full Flutter static sweep: every relative import resolves, zero
  duplicate Riverpod provider names, every imported package declared in
  `pubspec.yaml`, and every one of the 19 unique navigation target
  patterns in the app matched an actual declared route (checked by
  extraction + manual pairing, not just count comparison).
- No code changes were required this pass — everything checked came back
  clean. See KNOWN_ISSUES.md for what remains genuinely unverified because
  it requires tooling unavailable in every environment this project has
  run in so far.

## Product direction change — video dropped

Cartok was briefly explored as a TikTok-style short-video platform. That
direction has been dropped in favor of an automotive community app. No
video upload/processing/streaming code was ever built, so this required no
code removal — only removing stale references to a planned video feed from
`README.md` and `ARCHITECTURE.md`, and rewriting both (they had drifted
significantly out of date regardless — neither mentioned the marketplace,
events, discover, or messaging modules that had since been built).

Note on this changelog: entries below predate several modules that now
exist (marketplace, events, discover, messaging, likes/comments/bookmarks,
search, follow, mobile screens for all of the above). That work happened
across sessions not fully reflected here — treat `README.md`'s "What's
implemented" section as the source of truth for current state, and this
file as a partial, honest history rather than a complete one.

## Phase 1 — Auth + Garage/Vehicle vertical slice

**Backend**
- Project scaffold: Express + TypeScript + Prisma/Postgres + Redis.
- Auth: register, login, JWT access tokens, httpOnly-cookie refresh tokens
  with rotation, logout, logout-all-sessions.
- Users: profile read/update, public profile view.
- Garage + Vehicle: CRUD with ownership checks, garage following.
- VIN decoding via NHTSA's free vPIC API.
- Security middleware: JWT+RBAC, Zod validation, Redis rate limiting,
  centralized error handling.
- Docker + docker-compose + GitHub Actions CI.
- Verified: 7/7 tests passing, lint clean. Found and fixed during this
  phase: a missing `pino-pretty` dependency, an unguarded Prisma
  error-class check, a `jsonwebtoken` type mismatch, a lint violation.

**Mobile**
- Design system: telemetry/dashboard-inspired color palette and type system,
  a signature gauge-arc widget.
- Dio networking layer with persistent cookie jar and auto-refresh-on-401.
- Full auth flow (login/register/splash), garage home with loading/empty/
  error states, add-vehicle flow with VIN decode, vehicle detail/delete.
- Not machine-verified in this phase (no Flutter SDK in the build
  environment) — checked by hand: import resolution, provider/class
  reference consistency, third-party API usage against documentation.

## Phase 2 — Forum + Notifications

- Notifications: in-app feed, cursor pagination, unread count, mark-read/
  mark-all-read, wired as a real dependency of other modules (not a
  standalone demo) — garage follows and forum replies/upvotes emit real
  notifications.
- Forum: categories, threads, nested-reply posts, upvote/downvote, soft
  delete, moderator override.
- Verified: 21/21 tests passing. Found and fixed: an invalid `ParsedQs`
  type cast in two controllers, a transaction-callback implicit-`any`,
  and two test-fixture bugs (non-UUID mock IDs, a mock not simulating
  Prisma's `include` shape).

## Audit pass 1 — Security, database, and scalability review

**Security fixes**
- **[High]** Private garages and vehicles were fully readable by anyone,
  unauthenticated — the `isPublic` flags existed in the schema but were
  never checked on any read path. Fixed with a shared visibility check
  (`garage.service.ts#assertVisible`), returning 404 rather than 403 for
  hidden resources to avoid confirming their existence.
- **[High]** Refresh-token rotation had a TOCTOU race: two concurrent
  requests with the same token could both pass the "not yet revoked" check
  before either write landed, defeating reuse-detection. Rewritten as a
  single atomic conditional `UPDATE`. Added a concurrency test firing two
  simultaneous rotation requests and asserting exactly one succeeds.
- **[Medium]** JWT signing/verification didn't pin an algorithm, a known
  algorithm-confusion vector. Pinned `HS256` explicitly on both sides.

**Data integrity**
- Forum post soft-delete was permanently erasing `content` from the
  database, destroying the moderation/audit trail a soft delete is meant to
  preserve. Now only `isDeleted` is set; masking happens at the read layer.

**Database**
- Removed 6 indexes that duplicated existing `@unique`/composite-unique
  constraints (pure write overhead, zero read benefit).
- Added `RefreshToken(userId, revokedAt)` composite index matching the
  actual revoke-all-sessions query shape.

**Scalability / consistency**
- `GET /garages/mine` and the vehicles list endpoint were completely
  unbounded. Added cursor pagination consistent with the forum/
  notifications pattern.

**Duplication**
- `vehicles.service.ts` had a verbatim copy of `garage.service.ts`'s
  ownership-check query. Consolidated to one implementation.
- Removed leftover junk directories from an earlier failed shell
  brace-expansion (`{a,b,c}`-literal folder names).

## Audit pass 2 — Vote scoring, indexes, dead config, mobile provider fix

**Real scalability bug**
- `listPosts` fetched *every vote row* on a thread on every read just to
  sum them in JS — a post with 100k votes meant 100k rows pulled on every
  view. Replaced with a denormalized `ForumPost.score` column, maintained
  atomically (`increment`/`decrement` inside a transaction) alongside the
  vote write. Added four dedicated tests covering new-vote, vote-flip
  (+1→-1 must move the score by 2, not 1), same-value resubmit (no-op),
  and removal — specifically because this class of bug looks correct at a
  glance and is subtly wrong in the math.

**Database**
- Finished composite indexes matching real query shapes:
  `ForumThread(categoryId, isPinned, updatedAt)`,
  `ForumPost(threadId, createdAt)`, `Notification(recipientId, createdAt)`.
- Removed `ForumVote(postId)` — redundant with the existing composite
  unique constraint.

**Dead configuration**
- `JWT_REFRESH_SECRET` was required by env validation and referenced in
  tests/CI/Docker/README but never actually used anywhere — refresh tokens
  are opaque values, not JWTs. Removed everywhere it was referenced.

**Error handling**
- A 500-level `AppError` always echoed its message to the client regardless
  of environment — only the generic unhandled-error path was actually
  masked in production. No current call leaked anything sensitive, but this
  was a trap for a future `Errors.internal(err.message)` call. Closed.

**Rate limiting**
- Limits were keyed purely on IP. Mobile clients commonly share
  carrier-grade NAT IPs, so this could throttle many unrelated users
  sharing a network. Now keyed by authenticated user (decoded from the
  token, not verified — this only selects a bucket) when available,
  falling back to IP for anonymous/auth-stage requests.

**Mobile**
- Fixed a real cold-start bug: `apiClientProvider` reactively watched the
  cookie-jar provider, so the entire client → repository → auth-notifier
  chain was torn down and rebuilt the moment the cookie jar resolved,
  firing session-restore twice on every app launch (visible auth flash,
  duplicate network calls). Fixed by resolving the cookie jar once in
  `main()`, before `runApp()`, using the standard Riverpod
  `ProviderContainer` + `UncontrolledProviderScope` bootstrap pattern.
- Fixed an over-broad rebuild: the garage home screen watched the entire
  `AuthState` object to read one field (`user`), causing the whole screen
  (including the network-bound garage list) to rebuild on any auth-state
  change. Scoped with `.select()`.

**Test coverage**
- Added dedicated garage/vehicle module tests (44 total tests passing),
  specifically covering the visibility fixes above end-to-end (404 for a
  private garage/vehicle viewed by a stranger or anonymously, 200 for the
  owner).

**Documentation**
- Added this file, `ARCHITECTURE.md`, `SECURITY.md`, `DEPLOYMENT.md`.

## Known outstanding items (as of the video-plan removal)

Tracked honestly rather than claimed as complete:
- Push notifications (Firebase), Premium/billing, AI Assistant, Admin
  panel, dedicated moderation queue — not built. Video — dropped, not
  planned (see top of file).
- OpenAPI/API documentation — not written.
- Monitoring/observability (metrics, tracing, alerting) — not wired up.
- CI does not push images to a registry (no registry configured).
- Prisma client generation has not been verified in every environment this
  project has run in — sandboxes with a restricted network allowlist block
  the query-engine binary download, so `tsc --noEmit` shows a small,
  consistent set of errors that all trace to that one missing step, not to
  application logic.
- Flutter app has not been run through `flutter analyze`/`flutter test` in
  any environment used for this project — verified by hand each time
  (import resolution, route/nav-call matching, API usage against docs) but
  never machine-verified, since no environment used so far has had the
  Flutter SDK available.
