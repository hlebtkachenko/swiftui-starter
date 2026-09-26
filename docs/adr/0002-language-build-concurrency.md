# ADR-0002: Language, build toolchain, and concurrency

**Status:** Accepted - 2026-06-09; amended 2026-09-26 (toolchain moved to Xcode 27)

## Context

A greenfield app in 2026 built against the OS 27 SDK should adopt the current Swift toolchain and concurrency model from the start, rather than retrofitting strict concurrency later.

## Decision

- Use Xcode 27 with its bundled Swift 6.4 toolchain and the Swift 6 language mode (`SWIFT_VERSION = 6.0`; complete data-race safety / strict concurrency). Swift 6 is the newest language mode Xcode 27 offers (it accepts 4, 4.2, 5, and 6).
- Isolate the app target to the main actor by default, and take the approachable-concurrency easements (introduced in Swift 6.2).
- Set these explicitly (verified 2026-06-09): `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (the app-template default since Xcode 26, SE-0466) and the umbrella **Approachable Concurrency** build setting rather than the five flags one by one. Defer Strict Memory Safety while it is still noisy with macros.

## Consequences

- Data races become compile-time errors, caught before they ship.
- The concurrency learning curve is steeper, eased materially by main-actor-by-default for a UI app.
- Building requires a Mac on macOS 26.6 or later, per Xcode 27's `LSMinimumSystemVersion` (read from the installed Xcode 27.0 `Info.plist` on 2026-09-26). Running the macOS app and its tests needs macOS 27.

## Links

- Evidence: research report section 3 (language and tooling).
