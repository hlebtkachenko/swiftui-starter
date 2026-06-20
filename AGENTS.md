# AGENTS.md

Guidance for AI agents (Claude Code, Cursor, Copilot) working in this repo. `CLAUDE.md` is a symlink to this file. Detail lives in `docs/`; current state in `STATE.md`.

## This repo

A SwiftUI starter template for Apple-native, multiplatform apps (iPhone, iPad, Mac): App Store + TestFlight shaped. `AppName` is a placeholder you rename per app (see `README.md`). It ships a domain-agnostic spine plus one example feature (a family wishlist) that demonstrates the CloudKit + `CKShare` stack; replace the example with the real domain.

- **Public repo, proprietary** (`LICENSE`). Treat every file and CI log as world-readable.

## Platform and design (hard constraints)

- Targets: iPhone, iPad, Mac (native, multiplatform SwiftUI).
- Minimum OS 26 (iOS / iPadOS / macOS 26). No back-deployment.
- **Liquid Glass only:** use genuine system Liquid Glass APIs (`glassEffect`, `GlassEffectContainer`, `.glass` / `.glassProminent`). Never fake it with blurs, gradients, or third-party imitations. This is why the floor is OS 26.

## Stack

Decided and baked into the template; see `STATE.md` for the table and `docs/adr/` for the rationale. Swift 6 + SwiftUI, single multiplatform target, Observation (`@Observable`), Swift Package Manager (zero third-party deps), CloudKit + `CKShare` via Core Data (`NSPersistentCloudKitContainer`), Swift Testing. When starting a real app, revisit any decision that does not fit and update the ADR.

## Commands

Scheme `AppName` (rename with the app). Replace the simulator device name with one you have installed (`xcrun simctl list devices`).

```bash
xcodebuild build -scheme AppName -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test  -scheme AppName -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild build -scheme AppName -destination 'platform=macOS'
```

Secret scan before pushing (CI enforces the same):

```bash
gitleaks git --pre-commit --staged --redact --config .gitleaks.toml
```

## Boundaries (never)

- Never commit secrets, credentials, or signing assets. They go in untracked `Secrets.xcconfig`, CI secrets, or the Keychain.
- Never commit or invent personal/contact info (emails, names beyond the `LICENSE` holder, phones, infra). No contact email anywhere; point to GitHub.
- Never fake Liquid Glass; never add fallbacks for OS < 26.
- Never bypass the merge gates.
- Never duplicate documentation: each topic has one home (mapped in `docs/README.md`); link, do not restate.

Detail: `docs/security.md`.

## Engineering principles

1. **Think before coding:** surface assumptions and options; ask when unclear.
2. **Simplicity first:** minimum code, nothing speculative.
3. **Surgical changes:** touch only what the request needs.
4. **Goal-driven:** define how you will verify, then loop until it passes.

Full version and conventions: `docs/engineering.md`.

## CI gates (must pass to merge)

- `gitleaks` - secret scan.
- `guard` - blocks tracked secrets/private files, private keys, files over 5 MB, personal data, dead links, duplicate docs, and a stale ownership map.
- `pr-check` - Conventional Commits title and a real description.
- `codeql` - Swift scan.

Ruleset and release steps: `docs/ci-cd.md`.

## Done criteria

A task is done when: the change traces to the request and the required gates are green. Update `STATE.md` and `CHANGELOG.md` when they are affected, and the matching issue in whatever tracker the app uses.

## Versioning

Tags `vX.Y.Z`: X major (manual), Y feature (unbounded), Z fix. See `docs/ci-cd.md`.

## Conventions

- English only in code, comments, commits, docs.
- Conventional Commits (`feat`, `fix`, `docs`, `ci`, `chore`, `refactor`, `test`, `perf`, `build`, `style`, `revert`).
- Swift API Design Guidelines for naming.

## Index

- `docs/using-the-template.md` - step-by-step guide to start a new app from this template (clone, rename, sign, build, protect).
- `STATE.md` - what the template provides and how to start a new app from it.
- `docs/adr/` - architecture decision records: the founding stack decisions, one per record (canonical).
- `docs/` - engineering, security, CI/CD detail.
- `CHANGELOG.md` - history and versioning.
