# AGENTS.md

SwiftUI starter template for native multiplatform apps (iPhone, iPad, Mac), App Store and TestFlight shaped. `AppName` is a placeholder renamed per app ([docs/using-the-template.md](docs/using-the-template.md)). A domain-agnostic spine plus a generic shared-collection example (Folder / Item) that exercises CloudKit + `CKShare`, with no seed data; replace the example with the app's own model. Code map: [ARCHITECTURE.md](ARCHITECTURE.md). State: [STATE.md](STATE.md). Decisions: [docs/adr/](docs/adr/README.md).

Public repo, proprietary license: every file and CI log is world-readable.

## Hard constraints

- Deployment floor is OS 27 (iOS / iPadOS / macOS 27), built with Xcode 27. No back-deployment, no `#available` fallbacks below 27.
- Liquid Glass through system APIs only (`glassEffect`, `GlassEffectContainer`, `.glass` / `.glassProminent`); never imitated with blurs or gradients (ADR-0001).
- Zero third-party dependencies; first-party frameworks and SPM only (ADR-0004).
- No personal or contact data anywhere (emails, names beyond `LICENSE`, infra); support points to GitHub. The `guard` workflow enforces it ([docs/security.md](docs/security.md)).

## Commands

Scheme `AppName` (renamed with the app). Pick an installed simulator with `xcrun simctl list devices`.

```bash
xcodebuild build -scheme AppName -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test  -scheme AppName -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild build -scheme AppName -destination 'platform=macOS'
```

Local gate (mirrors the `guard` CI job), then the secret scan on staged files:

```bash
bash -c 'for s in .github/scripts/check-*.sh; do bash "$s" || exit 1; done'
gitleaks git --pre-commit --staged --redact --config .gitleaks.toml
```

Enable the pre-commit hook once per clone: `git config core.hooksPath .githooks`.

## Gotchas

- New Swift files need no `project.pbxproj` edit: the targets use filesystem-synchronized groups. Do not propose XcodeGen or Tuist (ADR-0015).
- Signing team lives in the gitignored `Secrets.xcconfig` (from `Secrets.xcconfig.example`), included by `Shared.xcconfig`.
- Never hardcode the bundle ID prefix: bundle IDs and the iCloud container use `$(BUNDLE_ID_PREFIX)`, set in `Secrets.xcconfig` locally and the `BUNDLE_ID_PREFIX` repo variable in CI (default `com.example`).
- CloudKit is off by default: `PersistenceController.cloudKitContainerIdentifier` is `nil`, so the app runs on a local store. Set it only after the container exists in the Developer portal and matches `com.apple.developer.icloud-container-identifiers` in `AppName.entitlements` (`Info.plist` needs nothing): an unprovisioned container crashes at launch.
- Every write goes through the concrete `AppNameStore` class; its `save()` rolls back and rethrows. Keep CloudKit calls inside the store and persistence types; tests use `PersistenceController(inMemory: true)` (ADR-0013).
- Identity is `NSManagedObjectID` (no `id` attribute); selection and share closures capture the object ID, never the managed object.
- Gate edits on `store.canEdit(_:)`: share participants may be read-only.
- `Shared.xcconfig` sets `SWIFT_TREAT_WARNINGS_AS_ERRORS` and `GCC_TREAT_WARNINGS_AS_ERRORS`, so any new warning fails the build.
- Docs: each topic has one home, mapped in [docs/README.md](docs/README.md). `check-duplication.sh` fails on any line of 45+ characters repeated verbatim across Markdown files, and `check-ownership-map.sh` fails when a new `.md` file is missing from the map.
- Accepted ADRs change only by a dated amendment or a superseding record ([docs/adr/README.md](docs/adr/README.md)).
- Required merge checks: gitleaks, guard, pr-check (Conventional Commits title + description), and `Build and test` from `build.yml` (macOS unit tests + iOS Simulator build; skipped on PRs without Swift or project changes). CodeQL (~17 min macOS build) is suspended as a gate until its tracer works with Xcode 27; it probes weekly and opens a restore PR itself. Detail and the release steps: [docs/ci-cd.md](docs/ci-cd.md).
- Update `STATE.md` and `CHANGELOG.md` (`## [Unreleased]`) when a change affects them.

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

The index is local and gitignored: `codegraph init --yes` builds it (the Conductor setup script in `.conductor/settings.toml` does this per workspace), `codegraph status` checks it. The MCP server is wired project-locally in `.mcp.json`.
