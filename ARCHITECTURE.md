# Architecture overview

How the template's code is laid out and how the pieces talk. Decisions and their rationale are in [docs/adr/](docs/adr/README.md); this file describes what the code does today.

## 1. Project structure

```
AppName.xcodeproj/          # one multiplatform app target + 2 test targets, synchronized folders
Shared.xcconfig             # shared build settings (warnings are errors); includes the gitignored Secrets.xcconfig
Secrets.xcconfig.example    # DEVELOPMENT_TEAM and BUNDLE_ID_PREFIX template (copy to Secrets.xcconfig)
AppName/
├── AppNameApp.swift        # @main: WindowGroup + macOS Settings scene, platform app delegates
├── ContentView.swift       # NavigationSplitView: folder sidebar + private FolderDetailView (items)
├── Core/                   # domain-agnostic spine
│   ├── AppEnvironment.swift    # composition root, injected into every scene; MetricKit loop
│   ├── SyncMonitor.swift       # folds CloudKit mirroring events into SyncState
│   ├── SyncState.swift         # SyncState, AccountState, CloudSyncEvent value types
│   ├── Connectivity.swift      # async NWPathMonitor + iCloud account status
│   └── Logging.swift           # OSLog Logger facade (bundle ID as subsystem, fixed categories)
├── Commands/               # menu and keyboard shortcuts shared by all platforms
├── Views/                  # SyncStatusChip, macOS SettingsView
├── Data/                   # example model + persistence
│   ├── AppNameStore.swift          # the store: writes, save with rollback, canEdit, CKShare calls
│   ├── AppNameModel.swift          # programmatic NSManagedObjectModel (no .xcdatamodeld)
│   ├── DemoContent.swift           # debug-only -demoContent seed (four folders with items)
│   ├── ManagedObjects.swift        # Folder / Item NSManagedObject subclasses + sorted fetch requests
│   └── PersistenceController.swift # NSPersistentCloudKitContainer, in-memory variant
├── Sharing/CloudSharing.swift  # CloudShareItem (Transferable for ShareLink), share-acceptance delegates
├── Info.plist, AppName.entitlements, PrivacyInfo.xcprivacy, Assets.xcassets
AppNameTests/               # Swift Testing: store, model CloudKit rules, sharing, spine
AppNameUITests/             # XCTest launch test
docs/                       # ADRs, CI/CD, security, patterns, template guide (map: docs/README.md)
.github/                    # workflows, guard scripts, main ruleset, CODEOWNERS
.githooks/pre-commit        # local large-file + gitleaks check
rename.sh                   # one-shot AppName -> YourApp rename (CI smoke-tests it)
llms.txt                    # short index for language models
docs/images/                # README screenshots (delete in your app)
.conductor/settings.toml    # Conductor workspace setup (CodeGraph index, Secrets.xcconfig copy)
.mcp.json                   # project-scoped CodeGraph MCP server
```

## 2. High-level diagram

```
[SwiftUI scenes] --@Environment--> [AppEnvironment]
                                      |-- SyncMonitor  <-- NSPersistentCloudKitContainer events
                                      |-- Connectivity <-- NWPathMonitor, CKContainer.accountStatus
                                      `-- AppNameStore --> PersistenceController
                                                             |-- .private SQLite store --\
                                                             `-- .shared SQLite store  ---+--> CloudKit (only when a container id is set)
```

Views read Core Data directly through `@FetchRequest` (`Folder.sortedFetchRequest()`, `Item.sortedFetchRequest(in:)`) on the injected `managedObjectContext`; every write goes through `AppNameStore`.

## 3. Core components

### 3.1 App (the only deliverable)

- Single native SwiftUI target for iPhone, iPad and Mac; deployment floor OS 27 (iOS / iPadOS / macOS 27), Swift 6 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, Swift and C warnings treated as errors.
- `AppNameApp` builds one `AppEnvironment(persistence: .shared)`, injects it and the view context into every scene, and calls `environment.start()` (guarded, runs once) from the first scene's `.task`.
- `AppEnvironment.displayState` composes store-load error, account, network and sync into the one status the chrome shows; a store-load error wins, then account problems and offline, then sync progress.
- The example UI uses system components only: folder sidebar and item list with swipe and context-menu delete, `ContentUnavailableView` empty states, a `ShareLink` shown only when sync is on, edits disabled when `store.canEdit(_:)` is false (read-only share participant). Strings go through `String(localized:)`.
- Debug builds accept `-seedProbe <title>` at launch to insert one folder, used to check cross-device sync by hand; `-demoContent` to fill an empty store with four named folders and their items (`Data/DemoContent.swift`, used for the README screenshots); and `-initializeCloudKitSchema YES` to push the Core Data schema to the CloudKit Development environment.
- Sharing entry points are platform-specific: on iOS the `SceneDelegate` receives `CKShare.Metadata` (cold and warm launch); on macOS the `NSApplicationDelegate` does. `Info.plist` declares `CKSharingSupported`.

## 4. Data stores

- **Core Data (SQLite, on device):** the source of truth. The template model is a generic shared collection: `Folder` (title, createdAt, to-many `items`, cascade) and `Item` (title, createdAt, to-one `folder`, nullify). No `id` attribute: identity is `NSManagedObjectID`; `createdAt` is set in `awakeFromInsert()` and is the sort key. Release builds ship no seed or sample data; debug builds seed demo content only on `-demoContent` and only into an empty store.
- **CloudKit (optional sync transport):** `PersistenceController.cloudKitContainerIdentifier` is `nil` in the template, so no CloudKit options are set and the app runs locally. With an identifier, the container pairs a `.private`-scope store with a `.shared`-scope store; a `CKShare` covers one folder and its items.
- **In-memory store:** `PersistenceController(inMemory: true)` (a `/dev/null` store, no CloudKit) backs the logic tests and the previews.

## 5. External integrations

Apple frameworks only, no third-party packages: CloudKit and `CKShare`, Network, MetricKit, OSLog, UIKit/AppKit sharing delegates. No custom server.

## 6. Deployment and infrastructure

- Distribution: App Store and TestFlight (Xcode Cloud per ADR-0014; not configured in this repo).
- GitHub Actions: `gitleaks`, `guard` (the `.github/scripts/check-*.sh` scripts), `pr-check`, `build` (unit tests on macOS, iOS Simulator build-for-testing), `codeql` (traced Swift build, weekly probe), `release-check` on `v*` tags. The `main` ruleset is code in `.github/rulesets/main.json`. Detail: [docs/ci-cd.md](docs/ci-cd.md).
- Monitoring: `Log` categories in Console / Instruments, MetricKit reports received through the async `MetricManager` and logged, Xcode Organizer crash reports. Nothing leaves the device through the app.

## 7. Security considerations

- Authentication: none in code yet; Sign in with Apple is the decided path (ADR-0011).
- Authorization: CloudKit enforces access; a `CKShare` participant is read-only or read-write, and the UI gates edits on `canUpdateRecord(forManagedObjectWith:)`.
- Secrets: signing team and bundle ID prefix, in the gitignored `Secrets.xcconfig`; the guard scripts and gitleaks block secrets, keys and personal data in the public repo ([docs/security.md](docs/security.md)).
- Privacy manifest: `AppName/PrivacyInfo.xcprivacy`.

## 8. Development and testing

- Setup and rename: [docs/using-the-template.md](docs/using-the-template.md). Commands and the local gate: [AGENTS.md](AGENTS.md).
- Tests: Swift Testing in `AppNameTests` (folder/item create, sort and cascade delete, save rollback, the model's CloudKit rules, sharing unavailable on the in-memory store, sync state and display precedence, the debug-only demo seed); one XCTest launch test in `AppNameUITests`. CloudKit sharing is verified only on signed builds with real iCloud accounts.
- Agent tooling: CodeGraph indexes the Swift sources into a gitignored `.codegraph/`; it is not part of the app.

## 9. Known gaps

- Folder / Item is a placeholder domain; replace it with the app's own model.
- No App Group container ships: each app decides before its first external build whether it needs one (ADR-0005). `REGISTER_APP_GROUPS = YES` stays as the Xcode template default and does nothing without the entitlement.
- Old development stores from the earlier example model will not open; reinstall. Stale record types in the CloudKit Development environment must not be deployed to Production.
- No app icon ships.

## 10. Project identification

AppName (template placeholder). Owner and reviewers: `.github/CODEOWNERS`; issues and security reports through the GitHub repository ([SECURITY.md](SECURITY.md)). Last updated 2026-09-26.
