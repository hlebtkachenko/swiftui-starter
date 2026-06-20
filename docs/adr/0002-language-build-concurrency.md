# ADR-0002: Language, build toolchain, and concurrency

**Status:** Accepted - 2026-06-09

## Context

A greenfield app in 2026 built against the OS 26 SDK should adopt the current Swift toolchain and concurrency model from the start, rather than retrofitting strict concurrency later.

## Decision

- Use Xcode 26, Swift 6.2, and the Swift 6 language mode (complete data-race safety / strict concurrency).
- Isolate the app target to the main actor by default, and take the Swift 6.2 approachable-concurrency easements.
- Set these explicitly (verified 2026-06-09): `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (the Xcode 26 app-template default, SE-0466) and the umbrella **Approachable Concurrency** build setting rather than the five flags one by one. Defer Strict Memory Safety while it is still noisy with macros.

## Consequences

- Data races become compile-time errors, caught before they ship.
- The concurrency learning curve is steeper, eased materially by main-actor-by-default for a UI app.
- Building requires a Mac on macOS Sequoia 15.6 or newer.

## Links

- Evidence: research report section 3 (language and tooling).
