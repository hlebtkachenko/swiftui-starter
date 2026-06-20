# AppName

A SwiftUI starter template for Apple-native, multiplatform apps (iPhone, iPad, Mac), built for **OS 26** with Apple's **Liquid Glass** design. Swift 6, zero third-party dependencies, App Store / TestFlight shaped.

`AppName` is a placeholder. Rename it to your app, drop in your own domain, and ship.

> **Status:** template, version 0.1.0. Ships a working spine plus one example feature. See [STATE.md](STATE.md).

## What you get

- **App spine** (`AppName/Core`, `AppName/Commands`, `AppName/Views`) - domain-agnostic and multiplatform: an `@Observable AppEnvironment` composition root (store, `AppRouter`, sync and connectivity monitors) injected into every scene, a shared `Commands` layer, a macOS `Settings` scene, CloudKit sync-state surfacing (`SyncState`, `ContentState<T>`, `SyncStatusChip`), an `OSLog` logging facade, a MetricKit subscriber (iOS), and a `PrivacyInfo.xcprivacy` manifest.
- **CloudKit + `CKShare` data layer** (`AppName/Data`, `AppName/Sharing`) - a programmatic Core Data model behind `NSPersistentCloudKitContainer`, a protocol-isolated store with an in-memory test double, paired `.private` / `.shared` stores, and `CKShare` role mapping. Demonstrated through one example feature (a family wishlist) you replace with your own.
- **Tests** - Swift Testing for logic, XCTest for UI and launch.
- **CI gates and governance** - gitleaks, guard, pr-check, CodeQL; a `LICENSE`, a `SECURITY.md`, and founding [Architecture Decision Records](docs/adr/README.md) documenting the stack and the OS 26 research behind it.

## Getting started

1. **Clone** and enable the local hooks: `git config core.hooksPath .githooks`.
2. **Rename** `AppName` to your app: find/replace `AppName` (and the lowercase `appname` in the bundle ID / container) across the tree, then rename the `AppName*` folders, files, and `AppName.xcodeproj`. Bundle IDs default to `dev.hapd.appname`; change the prefix to your own.
3. **Signing:** copy `Secrets.xcconfig.example` to `Secrets.xcconfig` and set `DEVELOPMENT_TEAM` (gitignored, never committed).
4. **Build:**

   ```bash
   xcodebuild build -scheme AppName -destination 'platform=iOS Simulator,name=iPhone 17'
   xcodebuild build -scheme AppName -destination 'platform=macOS'
   ```

5. **Replace the example domain** in `AppName/Data` with your own model and views.
6. **Turn on CloudKit (optional):** provision an iCloud container, set its identifier in `AppName.entitlements`, `AppName/Info.plist`, and `cloudKitContainerIdentifier` in `PersistenceController.swift` (it is `nil` by default, so the template runs as a local store with no iCloud setup).
7. **Protect `main`:** branch protection is a repo setting, not a file, so it does not carry over on copy. Reproduce it with `./.github/scripts/setup-branch-protection.sh` (needs the `gh` CLI with admin on your repo). See [docs/ci-cd.md](docs/ci-cd.md).

## Constraints

- Minimum OS 26 (iOS / iPadOS / macOS). No back-deployment.
- Liquid Glass only - genuine system APIs (`glassEffect`, `GlassEffectContainer`, `.glass` / `.glassProminent`); never faked with blurs or gradients. This is the reason for the OS 26 floor.

`main` is protected by a ruleset (checked in at `.github/rulesets/main.json`, applied with the script above); every pull request must pass **gitleaks**, **guard**, **pr-check**, and **CodeQL**. CI passes with **no repository secrets configured** - a fresh copy is green out of the box (`DEVELOPMENT_TEAM` and `FORBIDDEN_STRINGS` are optional). Releases are tagged `vX.Y.Z` and validated against the changelog.

## Documentation

- [STATE.md](STATE.md) - what the template provides and how to start a new app from it
- [AGENTS.md](AGENTS.md) - working guidance for AI agents and contributors (`CLAUDE.md` is a symlink to it)
- [docs/](docs/README.md) - engineering, security, CI/CD, and the ADRs
- [CHANGELOG.md](CHANGELOG.md) - history and the `vX.Y.Z` versioning scheme

## License

Proprietary. All rights reserved. See [LICENSE](LICENSE).
