# Architecture overview

How the template's code is laid out and how the pieces talk. Decisions and their rationale are in [docs/adr/](docs/adr/README.md); this file describes what the code does today.

## 1. Project structure

```
AppName.xcodeproj/          # one multiplatform app target + 2 test targets, synchronized folders
Shared.xcconfig             # shared build settings; includes the gitignored Secrets.xcconfig
Secrets.xcconfig.example    # DEVELOPMENT_TEAM template (copy to Secrets.xcconfig)
AppName/
├── AppNameApp.swift        # @main: WindowGroup + macOS Settings scene, platform app delegates
├── ContentView.swift       # placeholder Wishlists / Items shell for the example feature
├── Core/                   # domain-agnostic spine
│   ├── AppEnvironment.swift    # composition root, injected into every scene
│   ├── AppRouter.swift         # navigation state addressed by UUID
│   ├── SyncMonitor.swift       # folds CloudKit mirroring events into SyncState
│   ├── SyncState.swift         # SyncState, AccountState, CloudSyncEvent value types
│   ├── Connectivity.swift      # NWPathMonitor + iCloud account status
│   ├── ContentState.swift      # loading / empty / loaded / error screen state
│   ├── Logging.swift           # OSLog Logger facade (one subsystem, fixed categories)
│   └── MetricsSubscriber.swift # MetricKit payloads (iOS only)
├── Commands/               # menu and keyboard shortcuts shared by all platforms
├── Views/                  # ContentStateView, SyncStatusChip, macOS SettingsView
├── Data/                   # example domain + persistence
│   ├── AppNameStore.swift          # store protocol + Sendable domain structs
│   ├── CoreDataAppNameStore.swift  # Core Data implementation + CKShare calls
│   ├── AppNameModel.swift          # programmatic NSManagedObjectModel (no .xcdatamodeld)
│   ├── ManagedObjects.swift        # NSManagedObject subclasses
│   ├── PersistenceController.swift # NSPersistentCloudKitContainer, in-memory variant
│   ├── FamilySharing.swift         # sharing port, FamilyMember / FamilyRole
│   └── SampleData.swift            # deterministic seed for previews and tests
├── Sharing/CloudSharing.swift  # app/scene delegates for share acceptance, share sheet (temporary UI)
├── Info.plist, AppName.entitlements, PrivacyInfo.xcprivacy, Assets.xcassets
AppNameTests/               # Swift Testing: store, sharing mapping, spine
AppNameUITests/             # XCTest UI and launch tests
docs/                       # ADRs, CI/CD, security, patterns, template guide (map: docs/README.md)
.github/                    # workflows, guard scripts, main ruleset, CODEOWNERS
.githooks/pre-commit        # local large-file + gitleaks check
.conductor/settings.toml    # Conductor workspace setup (CodeGraph index)
.mcp.json                   # project-scoped CodeGraph MCP server
```

## 2. High-level diagram

```
[SwiftUI scenes] --@Environment--> [AppEnvironment]
                                      |-- AppRouter
                                      |-- SyncMonitor  <-- NSPersistentCloudKitContainer events
                                      |-- Connectivity <-- NWPathMonitor, CKContainer.accountStatus
                                      `-- CoreDataAppNameStore --> PersistenceController
                                                                    |-- .private SQLite store --\
                                                                    `-- .shared SQLite store  ---+--> CloudKit (only when a container id is set)
```

Views also read Core Data directly through `@FetchRequest` on the injected `managedObjectContext`.

## 3. Core components

### 3.1 App (the only deliverable)

- Single native SwiftUI target for iPhone, iPad and Mac; deployment floor OS 27 (iOS / iPadOS / macOS 27), Swift 6 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- `AppNameApp` builds one `AppEnvironment(persistence: .shared)`, injects it and the view context into every scene, and calls `environment.start()` from the first scene's `.task`.
- `AppEnvironment.displayState` composes account, network and sync into the one status the chrome shows (account problems and offline win over sync progress).
- Debug builds accept `-seedProbe <title>` at launch to insert a wishlist, used to check cross-device sync by hand.
- Sharing entry points are platform-specific: on iOS the `SceneDelegate` receives `CKShare.Metadata` (cold and warm launch); on macOS the `NSApplicationDelegate` does. `Info.plist` declares `CKSharingSupported`.

## 4. Data stores

- **Core Data (SQLite, on device):** the source of truth. Entities `Wishlist`, `WishItem`, `GiftClaim` (example domain). `GiftClaim.itemID` is a plain `UUID`, not a relationship, so claims stay out of the owner-visible share; the separate giver-only CloudKit zone is not built yet.
- **CloudKit (optional sync transport):** `PersistenceController.cloudKitContainerIdentifier` is `nil` in the template, so no CloudKit options are set and the app runs locally. With an identifier, the container pairs a `.private`-scope store with a `.shared`-scope store.
- **In-memory store:** `PersistenceController(inMemory: true)` (a `/dev/null` store, no CloudKit), used by the logic tests; `PersistenceController.preview()` seeds it with `SampleData` for previews.

## 5. External integrations

Apple frameworks only, no third-party packages: CloudKit and `CKShare`, Network, MetricKit, OSLog, UIKit/AppKit sharing delegates. No custom server.

## 6. Deployment and infrastructure

- Distribution: App Store and TestFlight (Xcode Cloud per ADR-0014; not configured in this repo).
- GitHub Actions: `gitleaks`, `guard` (the `.github/scripts/check-*.sh` scripts), `pr-check`, `codeql` (Swift build on macOS), `release-check` on `v*` tags. The `main` ruleset is code in `.github/rulesets/main.json`. Detail: [docs/ci-cd.md](docs/ci-cd.md).
- Monitoring: `Log` categories in Console / Instruments, MetricKit daily payloads logged on iOS, Xcode Organizer crash reports. Nothing leaves the device through the app.

## 7. Security considerations

- Authentication: none in code yet; Sign in with Apple is the decided path (ADR-0011).
- Authorization: CloudKit enforces access; a `CKShare` participant is read-only or read-write, and the share owner is shown as admin (`FamilyRole`).
- Secrets: signing team only, in the gitignored `Secrets.xcconfig`; the guard scripts and gitleaks block secrets, keys and personal data in the public repo ([docs/security.md](docs/security.md)).
- Privacy manifest: `AppName/PrivacyInfo.xcprivacy`.

## 8. Development and testing

- Setup and rename: [docs/using-the-template.md](docs/using-the-template.md). Commands and the local gate: [AGENTS.md](AGENTS.md).
- Tests: Swift Testing in `AppNameTests` (serialized suites over the in-memory store, pure sharing-role mapping, sync state machine, router); XCTest in `AppNameUITests`. CloudKit sharing is verified only on signed builds with real iCloud accounts.
- Agent tooling: CodeGraph indexes the Swift sources into a gitignored `.codegraph/`; it is not part of the app.

## 9. Known gaps

- The sharing UI in `Sharing/CloudSharing.swift` and the `ContentView` shell are scaffolding for the example feature.
- The store is not yet in an App Group container (ADR-0005 recommends it before any widget).
- No app icon ships.

## 10. Project identification

AppName (template placeholder). Owner and reviewers: `.github/CODEOWNERS`; issues and security reports through the GitHub repository ([SECURITY.md](SECURITY.md)). Last updated 2026-09-26.
