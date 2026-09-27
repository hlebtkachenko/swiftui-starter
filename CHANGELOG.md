# Changelog

All notable changes to this project are documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Release tags use `vX.Y.Z`; the rules and release steps are in [docs/ci-cd.md](docs/ci-cd.md).

## [Unreleased]

### Added
- House rules in `docs/patterns.md`: priority order for conflicting goals, `final` classes, one primary type per file, a `#Preview` per SwiftUI view, no side effects in `init`, and no Mac Catalyst.
- ADR-0005 amended: once the CloudKit schema reaches Production, schema changes are additive only, and conflict resolution is pinned by a unit test.
- Localization conventions in `docs/patterns.md`: String Catalogs from the first screen, translator comments, plural variations, and leading/trailing layout.
- `swift format` configuration (`.swift-format`) and format/lint commands in AGENTS.md; `#Preview` for `SettingsView` and `SyncStatusChip`.

### Changed
- **Breaking:** the deployment floor is now OS 27 (iOS / iPadOS / macOS 27), built with Xcode 27. Apps that must run on OS 26 should stay on 0.2.x. ADR-0001 and ADR-0002 are amended; ADR-0008 and ADR-0010 note that the OS 27 APIs they mention are now within the floor.
- CodeQL is no longer a required PR check: its Swift tracer cannot build with the arm64-only Xcode 27 helpers on GitHub's runner. It runs weekly and on demand as a probe, and its first green run opens a PR that restores the gate.
- Agent setup follows one file: `AGENTS.md` holds the agent instructions and the `CLAUDE.md` symlink is removed. `ARCHITECTURE.md` maps the code. ADR-0015 is amended accordingly.
- Docs trimmed to one home per topic: `docs/engineering.md` is folded into `docs/patterns.md`, the CI gate tables in `docs/ci-cd.md` are merged, the research report is marked historical, and `README.md` / `STATE.md` point to the guide and `ARCHITECTURE.md` instead of repeating them.

- The family wishlist example is replaced by a generic shared-collection example: `Folder` and `Item` Core Data entities (identity by object ID, `createdAt` as sort key, cascade delete), a system-component UI (split view, empty states, `ShareLink`), and no seed or sample data. `-seedProbe` now creates a folder. Old development stores from the previous model do not open; reinstall.
- The store is one concrete `AppNameStore` class; the store protocol, value structs, and mapping layer are gone. ADR-0005, 0006, 0007, 0013, and 0016 are amended to drop the family framing.

### Performance
- The folder detail view looks up the folder's CloudKit share once per folder and after each finished sync, instead of on every view update.

### Fixed
- Deleting the selected folder, on this device or another, clears the selection and shows the "No Folder Selected" placeholder.
- MetricKit reports come through the async `MetricManager`, fixing a main-actor isolation trap in the delegate callback.
- Sharing reuses an existing `CKShare` instead of creating a new one each time, including a second tap before the first share has synced (the prepare path looks up existing shares first), and the share button shows only when sync is on.
- Sync errors persist until an event succeeds, and a store-load error keeps precedence in the status chip.
- A failed save rolls back the context and the error is logged instead of swallowed.
- Read-only share participants can no longer add, edit, or delete.
- The spine monitors start once, not once per window; New moves off the macOS New Window shortcut.

### Removed
- `ContentState`, `AppRouter`, the `FamilySharing` protocol and member/role types, `SampleData`, the `GiftClaim` feature, the store protocol, the dead app-delegate share handler, and unused privacy reasons and build settings.

### Added
- The bundle ID prefix is a build setting, `BUNDLE_ID_PREFIX`, instead of a hardcoded value: set it in the gitignored `Secrets.xcconfig` and as a GitHub repository variable that CI writes into that file. Without it, bundle IDs fall back to `com.example.appname`. The log subsystem now follows the bundle ID.
- A `build` workflow with the required `Build and test` check: macOS unit tests and an iOS Simulator build-for-testing on every PR that touches Swift or project files (docs-only PRs skip the macOS job).
- The weekly CodeQL probe re-enables itself on each run, so GitHub's 60-day inactivity rule is less likely to switch it off.
- CodeGraph code index for agents: project-scoped MCP server in `.mcp.json`, `mcp__codegraph__*` allowed in `.claude/settings.json`, a Conductor setup script that builds the gitignored `.codegraph/` index per workspace. ADR-0004 records it as developer tooling, not an app dependency.

## [0.2.1] - 2026-06-20

### Added
- `docs/using-the-template.md`: a step-by-step guide to start a new app from this template (get a copy, rename `AppName`, signing, build, protect `main`, replace the example domain). Linked from `README.md`, `AGENTS.md`, and the ownership map.

## [0.2.0] - 2026-06-20

### Added
- Branch protection as code: the `main` ruleset is checked in at `.github/rulesets/main.json` and applied with one idempotent command, `./.github/scripts/setup-branch-protection.sh`. A ruleset is a repository setting that does not travel with a clone or fork, so a fresh copy can now reproduce the same protection (PR required, the four required status checks, linear history, no force-push or deletion) instead of relying on settings that silently fail to carry over.

### Changed
- CI passes with no repository secrets configured, so a fresh copy is green out of the box. The CodeQL build disables code signing, making the `DEVELOPMENT_TEAM` secret optional; `FORBIDDEN_STRINGS` was already optional in the personal-data guard. Documented under "Forks and secrets" in `docs/ci-cd.md`.

## [0.1.0] - 2026-06-20

### Added

- Initial template: an Apple-native, multiplatform (iPhone, iPad, Mac) SwiftUI starter for OS 26 with Liquid Glass, Swift 6, and zero third-party dependencies. Single multiplatform Xcode target with `AppNameTests` (Swift Testing) and `AppNameUITests`; signing team supplied out of band via a gitignored `Secrets.xcconfig` wired through `Shared.xcconfig`.
- Domain-agnostic app spine (`AppName/Core`, `AppName/Commands`, `AppName/Views`): an `@Observable AppEnvironment` composition root (store, `AppRouter`, `SyncMonitor`, `Connectivity`) injected into every scene, a shared `Commands` layer, a macOS `Settings` scene, CloudKit connectivity and sync-state surfacing (`SyncState`, `ContentState<T>`, `SyncStatusChip`), an `OSLog` `Logger` facade, a MetricKit subscriber (iOS), and a `PrivacyInfo.xcprivacy` manifest.
- A CloudKit + `CKShare` data layer (`AppName/Data`, `AppName/Sharing`) shown end to end through one example feature (a family wishlist): a programmatic Core Data model behind `NSPersistentCloudKitContainer`, a protocol-isolated store with a Core Data implementation and an in-memory test double, paired `.private` / `.shared` stores, `CKShare` role/permission mapping, and a temporary on-device sharing surface. Sync is **off by default** (`cloudKitContainerIdentifier` is `nil`, so the app runs as a local store); set the identifier and provision a container to turn it on. Replace the example domain with your own.
- Swift Testing coverage for the spine (sync state machine, error/account mapping, the router, composed display state) and the example data layer; macOS and iOS Simulator builds and the test suite pass.
- Governance and CI: `AGENTS.md` (+ `docs/`), `LICENSE`, `SECURITY.md`, a set of founding Architecture Decision Records (`docs/adr/0001`-`0017`), and the OS 26 research report behind them. Merge gates: gitleaks, guard (secrets / private files / large files / personal data / dead links / duplicate docs / ownership map), pr-check (Conventional Commits), and CodeQL.
