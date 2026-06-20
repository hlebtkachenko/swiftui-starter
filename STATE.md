# Project state

Developer- and agent-facing snapshot. Read this first to know what exists and what to do next. Rules and conventions live in `AGENTS.md` and `docs/`.

This is a **template** (`AppName` is a placeholder). Once you start a real app from it, rewrite this file to describe that app's state.

- **What this is:** a SwiftUI starter for Apple-native, multiplatform apps (iPhone, iPad, Mac).
- **Platform:** minimum OS 26; Liquid Glass only.
- **Version:** 0.2.0. Ships a working, tested spine plus one example feature (a family wishlist) demonstrating the CloudKit + `CKShare` stack. CI passes with no secrets configured, and the `main` ruleset is reproducible from the repo (see `docs/ci-cd.md`).

## Stack

| Area | Decision |
|------|----------|
| Language / UI | Swift 6, SwiftUI, single multiplatform target |
| Minimum OS | 26 (iOS / iPadOS / macOS) |
| Design | System Liquid Glass only |
| Architecture | Observation (`@Observable`) model-view; per-screen view model only when a screen needs it |
| Dependency manager | Swift Package Manager; zero third-party dependencies to start |
| Backend / data | CloudKit + `CKShare` via Core Data + `NSPersistentCloudKitContainer`; local store as source of truth; no custom server. Sync is **off by default** (local store) until you provision a container |
| Search | Local Core Data predicates + Core Spotlight; no raw FTS5 |
| File storage | `CKAsset` (Core Data external storage) in the owning record's iCloud |
| Push | APNs via CloudKit (background sync + share invites) |
| Auth | Sign in with Apple (the example assumes it; adapt to your app) |
| Test framework | Swift Testing; XCTest only for UI automation and performance |
| AI | None; later on-device Foundation Models only (no third-party/cloud LLM) |
| Observability | First-party only: `OSLog`, MetricKit, Xcode Organizer, App Store Connect analytics |
| CI | Xcode Cloud (build/test/sign/ship) + GitHub Actions (repo gates + tag-push release) |

The decisions live as ADRs in `docs/adr/` (0001-0017); the research report `docs/plans/os26-apple-native-research.md` holds the rationale, trade-offs, and Apple citations behind them. They reflect the choices baked into the template; revisit any that do not fit your app.

## What exists

- Governance docs: `AGENTS.md` (+ `docs/`), `LICENSE`, `SECURITY.md`, `CHANGELOG.md`.
- CI gates: gitleaks, guard (secrets / private / large / personal data / links / ownership map), pr-check, codeql, release-check.
- Xcode multiplatform project (`AppName.xcodeproj`): `AppName` app + `AppNameTests` (Swift Testing) + `AppNameUITests`; signing team in a gitignored `Secrets.xcconfig` wired via `Shared.xcconfig`.
- App spine (`AppName/Core`, `AppName/Commands`, `AppName/Views`): a domain-agnostic, multiplatform foundation independent of any feature - the `AppEnvironment` composition root, `AppRouter`, `SyncMonitor`, `Connectivity`, a `Commands` layer, a macOS `Settings` scene, sync-state surfacing, an `OSLog` facade, a MetricKit subscriber, and a privacy manifest.
- Example data layer (`AppName/Data`, `AppName/Sharing`): a programmatic Core Data model (`Wishlist`, `WishItem`, partitioned `GiftClaim`) on `NSPersistentCloudKitContainer`; the store protocol with a Core Data implementation and an in-memory test double; deterministic sample data; `CKShare` role mapping; a temporary on-device sharing surface; a placeholder Wishlists/Items SwiftUI shell.
- Swift Testing cases covering the sync state machine, error/account mapping, the router, and the example data layer; macOS and iOS Simulator builds and the test suite pass.

## Start a new app from this template

1. Clone, then enable local hooks: `git config core.hooksPath .githooks`.
2. Rename `AppName` to your app (see `README.md`), set `DEVELOPMENT_TEAM` in `Secrets.xcconfig`, and confirm both builds pass.
3. Read `AGENTS.md` for constraints and boundaries.
4. Replace the example domain in `AppName/Data` with your own model and views.
5. To enable sync: provision an iCloud container and set `cloudKitContainerIdentifier` (it is `nil` by default).
6. Rewrite `README.md`, this file, and `CHANGELOG.md` for your app; revisit the ADRs that do not fit.

## Notes carried from the source project

- The example sharing UI is temporary scaffolding; build a real, owner/participant-aware family-sharing UI if you keep that feature.
- The gift-claim partition is enforced at the model level (a claim references its item by `UUID`, never a relationship); the physical giver-only CloudKit zone is a follow-up.
- Deploy the CloudKit schema Development -> Production before the first external-TestFlight/production build (ADR-0014).
- No app icon ships with the template.
