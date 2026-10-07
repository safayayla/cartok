# Cartok v1.0.0-beta — Release Notes

Cartok is an automotive community platform: garages and vehicles, a forum,
a marketplace, meetups (Cars & Coffee / Drive Together), messaging, and a
community feed that blends all of it. **There is no video platform** — an
earlier TikTok-style direction was explored and permanently dropped; see
`ARCHITECTURE.md` if you're wondering why it isn't here.

## What's in this beta

- **Auth**: register, login, JWT access tokens, httpOnly refresh-cookie
  rotation with reuse-detection, logout.
- **Garage & Vehicles**: create garages, add vehicles (with VIN decode),
  ownership + visibility rules (private garages/vehicles are actually
  private), like, comment, bookmark.
- **Forum**: categories, threads, nested replies, voting, bookmarks.
- **Marketplace**: listings with search/filter, favorites.
- **Events**: Cars & Coffee, Drive Together, track days, meetups — RSVP
  with race-safe capacity enforcement, QR check-in.
- **Community feed**: a real (heuristic, not ML) recommendation feed
  blending vehicles, forum threads, and events.
- **Messaging**: 1:1 conversations. REST + 4-second client polling, not a
  WebSocket — see "Known limitations" below.
- **Search**: garages, users, and marketplace listings.
- **Notifications**: in-app feed, driven by real events across every
  module above (a like, a follow, a reply — not a demo feed).
- **Profiles**: follow/unfollow, bookmarks, edit profile.

## Known limitations in this beta

- **No push notifications.** No Firebase project exists yet. In-app
  notifications work; nothing arrives when the app is closed.
- **No real-time messaging.** Polling every 4 seconds while a
  conversation is open. Functional, not instant.
- **No Premium/billing, no AI Assistant, no admin panel.** None of these
  have a line of code yet — each needs a decision (payment processor,
  model provider) or dedicated build effort this beta doesn't include.
- **No photo upload.** Vehicles and listings take image *URLs*, not file
  uploads — you need to already have a hosted image.
- **No Android or iOS platform folders exist in this repository yet.**
  `flutter create` needs a Flutter SDK, which has not been installable in
  any environment this project has used (`storage.googleapis.com`,
  where the SDK is distributed, is blocked). This is a beta of the
  *application code*, not yet a build artifact — see BETA_CHECKLIST.md for
  the exact steps to generate a real installable build once you have the
  SDK.
- **`backend/package-lock.json` and `backend/prisma/migrations/` were
  missing and have now been added** (2026-10-05 fix pass) —
  `package-lock.json` was generated from the current `package.json` and
  verified with a clean `npm ci`; the initial migration was written from
  the current `schema.prisma` and verified by applying it directly to a
  real PostgreSQL 16 database. `prisma generate`/`migrate deploy`
  themselves still could not be executed in that session — see below.

## Verification status for this release — read before trusting it

The backend has a 131-test suite, and it was re-executed for real in this
session (2026-10-06): **131/131 passing, 9/9 suites** (`npm test`). Also
run for real this session: `npm ci` ✅ and `npm run lint` ✅ (0 errors).
`npx prisma generate` failed — `binaries.prisma.sh` returned `403
Forbidden` from this session's egress proxy — which cascades into 8
`tsc`/`build` errors (`npm run build` exits non-zero, though it still
emits `dist/`), but does **not** affect the test suite, since every test
file mocks the Prisma client module before import rather than using the
generated one. A real PostgreSQL 16 database was available this session
and was used to verify the new migration SQL directly, bypassing Prisma's
own CLI for that one check. See TESTING.md for the full, current,
command-by-command breakdown of what's actually been executed versus
blocked versus statically checked.

The Flutter app has never been compiled in any environment this project
has used — no Flutter SDK has been available. 21 real tests now exist
across 6 files in `mobile/test/` (written 2026-10-05) but have likewise
never been executed, for the same SDK reason. Every change has also been
checked by hand (import resolution, route/navigation-call matching,
design-token validity, package declarations) — a real safety net that has
caught real bugs, but not a substitute for `flutter analyze`/`flutter
test`.

**Do not treat this as a verified build.** Treat it as application code
that is, by the most rigorous checking available in every environment it's
been developed in, structurally sound and logically consistent — and that
still needs `prisma generate`, `npm test`, `flutter pub get`, `flutter
analyze`, and `flutter test` run for real, by someone with unrestricted
tooling, before it ships. This is not "production ready"; it is a
buildable, installable beta codebase once those commands are run
successfully somewhere with normal internet access.

## Versioning

This is `v1.0.0-beta`. There is no prior public release.
