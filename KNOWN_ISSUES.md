# Known Issues

Grouped by why they're unresolved, not by severity — because "why" is what
tells you whether it's a code problem (fixable now) or an external
dependency (not fixable without a decision/credential this document can't
supply).

## Release blockers still open after the 2026-10-05 fix pass

These three are blocked on tooling that genuinely cannot be installed or
reached from this sandboxed environment — not on undecided product
questions, and not hidden by documentation changes. Each was independently
confirmed (not assumed) by actually attempting the command and reading the
real error:

- **`prisma generate` / `prisma migrate deploy` cannot run.**
  `binaries.prisma.sh` (where Prisma's query/schema-engine binaries are
  hosted) returns `403 Forbidden` from this environment's egress proxy.
  Workaround applied: the initial migration SQL was hand-written from the
  current `schema.prisma` and verified by applying it directly to a real
  PostgreSQL 16 database with `psql` (25 tables, 0 errors) — but this is
  not the same as Prisma's own tooling confirming it, and the backend's
  `tsc`/`build`/`test` all currently fail because the Prisma Client's
  TypeScript types are never generated. **Fix**: run `npx prisma generate
  && npx prisma migrate deploy` on any machine with normal internet
  access — this is expected to just work there.
- **`mobile/android/` and `mobile/ios/` platform folders do not exist.**
  Generating them needs `flutter create .`, which needs a Flutter SDK
  installed, which needs `storage.googleapis.com` — also blocked here (and
  on every other environment this project has used so far). **Fix**: on a
  machine with Flutter installed, run `flutter create . --platforms=android,ios`
  from `mobile/`, then set the Android `applicationId` and iOS bundle
  identifier to `com.cartok.app` if the generated defaults differ.
- **`docker build` on the backend cannot be verified end-to-end.** The
  Dockerfile itself is correct (still uses `npm ci`, not `npm install`,
  and the daemon runs fine here) but `registry-1.docker.io` — Docker Hub,
  needed to pull the `node:20-alpine` base image — is also blocked by the
  same proxy policy. **Fix**: run `docker build` on a machine with normal
  internet access, or point the registry mirror at an internal cache if
  your organization runs one.

## Blocked on an external decision or credential (not a code problem)

- **Push notifications**: no Firebase project exists. Needs: a real
  Firebase project, `google-services.json` (Android) /
  `GoogleService-Info.plist` (iOS), and backend integration to send via
  FCM. Zero code exists for this yet.
- **Premium/billing**: no payment processor decision has been made
  (Stripe vs. RevenueCat vs. platform-native IAP). No schema, no code.
- **AI Assistant**: no model/API provider has been chosen, no prompt
  design work has started.
- **Real-time messaging**: works today via REST + 4-second client-side
  polling (see ARCHITECTURE.md), which is honest and functional but not
  actually real-time. Upgrading to a WebSocket needs a hosting decision
  (managed service vs. self-hosted) before code is worth writing.
- **Video**: permanently dropped as a product direction, not blocked —
  listed here only so it isn't confused with the "blocked" items above.

## Genuinely unbuilt, no external blocker

- **Admin panel**: no dedicated admin UI exists. RBAC (`MODERATOR`/`ADMIN`
  roles) exists and is used inline in the forum module (post moderation
  override), but there's no dashboard, no moderation queue, no
  user-management UI.
- **Moderation queue / reporting flow**: users have no way to report a
  post/listing/user in-app. Moderators can only act on content they
  already know about via direct database/API access.
- **Vehicle photo galleries**: vehicles support a single implicit state
  today, not a multi-photo gallery. Marketplace listings do support
  multiple photo URLs; vehicles don't yet.
- **Photo/image upload**: no object-storage integration exists anywhere
  (marketplace listings and vehicles both accept photo *URLs*, not file
  uploads — the client is expected to already have a hosted URL). Needs an
  S3/Cloudflare R2/etc. decision.
- **Email verification**: `User.emailVerifiedAt` exists in the schema and
  is unused. No verification email is ever sent.
- **2FA/MFA**: not implemented.

## Verification gaps (may or may not be bugs — genuinely unknown)

- **21 Flutter tests now exist (6 files) but have never been executed**
  (see TESTING.md) — no Flutter/Dart SDK is installable in any
  environment this project has used. Static consistency checks have been
  thorough and have caught real bugs, but neither they nor an unexecuted
  test file are a substitute for an actual `flutter test` run.
- **Backend tests run against a hand-written Prisma mock, not real
  Postgres.** The mocks have had real bugs found and fixed in them
  multiple times during development (most recently: a mock not honoring
  a `select` clause, which would have hidden whether a security fix
  actually worked). A test suite passing against these mocks is good
  signal, not proof of correctness against a real database — the CI
  workflow spins up real Postgres/Redis containers for the build step but
  the test suite itself has not been run against them.
- **No load testing has been performed at any point.** Nothing is known
  about behavior under concurrent load beyond the specific, deliberately
  targeted concurrency tests (refresh-token rotation, event RSVP
  capacity) — both of which exist precisely because a real race condition
  was found and fixed, not as general load-testing coverage.
- **This session (2026-10-06) had npm, Postgres and Docker, but not
  Prisma's engine binary, Docker Hub, or a Flutter SDK** — see the
  release-blockers section at the top of this document and TESTING.md's
  environment limitations section for exactly what ran versus what was
  blocked and why. The "131/131 backend tests passing" figure **was**
  re-verified directly in this session (`npm test`, 9/9 suites) — it does
  not depend on `prisma generate` because every suite mocks the Prisma
  client module before import. `prisma generate`/`migrate deploy` and
  `docker build` remain genuinely blocked by the egress proxy, confirmed
  by direct `curl` and by the commands' own error output, not assumed.

## Explicitly NOT planned (by product decision, not oversight)

- Video upload, processing, streaming, or video-based recommendations —
  dropped as a product direction. Do not re-add without an explicit new
  decision to revisit it.
- Group messaging — `Conversation.isGroup` exists in the schema for
  forward compatibility but the service layer only ever creates/queries
  1:1 DMs.
