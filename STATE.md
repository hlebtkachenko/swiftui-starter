# Project state

Snapshot of what exists. Code layout lives in `ARCHITECTURE.md`, agent instructions in `AGENTS.md`, decisions in `docs/adr/`.

This is a **template** (`AppName` is a placeholder). Once you start a real app from it ([docs/using-the-template.md](docs/using-the-template.md)), rewrite this file to describe that app's state.

- **Platform:** minimum OS 27 (iOS / iPadOS / macOS 27), built with Xcode 27; Liquid Glass only.
- **Version:** 1.0.0 released (OS 27 floor, generic example, agent tooling; see `CHANGELOG.md`).

## Stack

| Area | Decision |
|------|----------|
| Language / UI | Swift 6, SwiftUI, single multiplatform target |
| Minimum OS | 27 (iOS / iPadOS / macOS), Xcode 27 |
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
| CI | Xcode Cloud (build/test/sign/ship) + GitHub Actions (repo gates, PR build and test, tag-push release) |
| Agent tooling | `AGENTS.md` + `ARCHITECTURE.md`; CodeGraph index (local, gitignored) via project `.mcp.json` |

Each row is an ADR in `docs/adr/` (0001-0017); revisit any that does not fit your app.

## What exists

- Xcode project `AppName.xcodeproj`: the `AppName` app, `AppNameTests` (Swift Testing), `AppNameUITests`; signing team in a gitignored `Secrets.xcconfig` wired via `Shared.xcconfig`.
- App spine (`AppName/Core`, `AppName/Commands`, `AppName/Views`) and the Folder / Item example (`AppName/Data`, `AppName/Sharing`, `ContentView.swift`), described in `ARCHITECTURE.md`.
- Debug builds take `-demoContent` to fill an empty store with four named folders and their items; Release builds ship no seed data.
- Swift Testing cases for the store (create, sort, cascade delete, save rollback, merge policy), the model's CloudKit rules, sharing on an in-memory store, and sync state and display precedence, and the debug-only `-demoContent` seed.
- CI gates: gitleaks, guard, pr-check, build (macOS tests + iOS Simulator build), release-check; codeql runs weekly as an Xcode 27 probe until it can gate again; the `main` ruleset as code (`docs/ci-cd.md`).

## Known gaps

- Folder / Item is a placeholder model with a minimal system-component UI; replace both with the app's own domain.
- No App Group container ships; decide per app before the first external build (ADR-0005).
- Deploy the CloudKit schema Development -> Production before the first external-TestFlight/production build (ADR-0014).
- No app icon ships with the template.
- No String Catalog ships yet; spine status strings (`SyncState.label`, `SyncErrorMapper`) are plain `String`, not localized.
