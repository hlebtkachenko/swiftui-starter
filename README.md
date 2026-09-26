# AppName

A SwiftUI starter template for Apple-native, multiplatform apps (iPhone, iPad, Mac), built for **OS 27** (iOS / iPadOS / macOS 27, Xcode 27) with Apple's **Liquid Glass** design. Swift 6, zero third-party dependencies, App Store / TestFlight shaped.

`AppName` is a placeholder. Rename it to your app, drop in your own domain, and ship.

> **Status:** template. Ships a working spine plus one example feature (a family wishlist on CloudKit + `CKShare`). See [STATE.md](STATE.md).

## What you get

- A domain-agnostic app spine: composition root, router, sync and connectivity monitors, shared commands, macOS Settings, `OSLog` and MetricKit, a privacy manifest.
- A CloudKit + `CKShare` data layer behind a store protocol with an in-memory test double, shown through the example feature you replace.
- Swift Testing for logic, XCTest for UI.
- CI gates (gitleaks, guard, pr-check, CodeQL), a reproducible `main` ruleset, and founding [Architecture Decision Records](docs/adr/README.md).

Code layout: [ARCHITECTURE.md](ARCHITECTURE.md).

## Getting started

Follow [docs/using-the-template.md](docs/using-the-template.md): copy, rename `AppName`, set the signing team, build, protect `main`, replace the example domain. CloudKit sync is off until you provision a container, so a fresh copy runs as a local store.

## Constraints

- No back-deployment below OS 27.
- Liquid Glass only through genuine system APIs (`glassEffect`, `GlassEffectContainer`, `.glass` / `.glassProminent`), never faked with blurs or gradients; that is why the floor tracks the newest OS.

Every pull request to `main` must pass gitleaks, guard, pr-check, and CodeQL. CI needs **no repository secrets** to go green. Releases are tagged `vX.Y.Z`; see [docs/ci-cd.md](docs/ci-cd.md).

## Documentation

- [AGENTS.md](AGENTS.md) - instructions for AI agents and contributors: commands, local gate, gotchas
- [ARCHITECTURE.md](ARCHITECTURE.md) - code layout and data flow
- [STATE.md](STATE.md) - what the template provides today
- [docs/](docs/README.md) - the docs map: CI/CD, security, patterns, ADRs
- [CHANGELOG.md](CHANGELOG.md) - history

## License

Proprietary. All rights reserved. See [LICENSE](LICENSE).
