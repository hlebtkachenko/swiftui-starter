# ADR-0013: Testing strategy

**Status:** Accepted - 2026-06-09

## Context

Swift Testing is Apple's modern framework, and the app is largely agent-developed, which rewards a fast headless loop. CloudKit, however, has no headless test harness: real sharing needs signed builds and live iCloud accounts.

## Decision

- Write unit and logic tests with Swift Testing; keep XCTest only for UI automation (XCUITest) and performance.
- Test in two layers:
  1. Isolate CloudKit behind a persistence/sync protocol and test the logic core against an in-memory double, which runs headless and deterministically and is the loop an agent can drive.
  2. Verify CloudKit and `CKShare` integration on signed builds with real iCloud accounts, drive the Mac app through computer-control, and exercise sharing with a second iCloud account.

## Consequences

- Almost all behavior is covered by the fast layer; CloudKit and UI correctness remain device-and-account integration that is partly manual.
- Dependency inversion around CloudKit is mandatory, not optional, for this split to work, which reinforces [ADR-0003](0003-ui-state-architecture.md).
- Patterns (verified 2026-06-09): run in-memory-double suites under `@Suite(.serialized)` since tests parallelize by default over a shared store; prefer `struct`/`actor` suites; parameterize over `CaseIterable` with `@Test(arguments:)`; assert throwing with `#expect(throws:)` / `#require(throws:)` (the former returns the error for follow-up checks); use `confirmation()` for async callbacks; and use exit tests (`#expect(processExitsWith:)`) to cover model `precondition`/`fatalError` guards.
- Preview/seed recipe (from Apple's Backyard Birds sample): a `.appNameDataContainer(inMemory:)` modifier builds an in-memory `NSPersistentCloudKitContainer`, seeds it from per-entity `+SampleData` files via a deterministic generator, and feeds a generic `ModelPreview<Entity>` wrapper; the same in-memory container is the test double, so previews and tests share one store. See `docs/patterns.md`.

## Links

- Evidence: research report section 3.1 (Swift Testing vs XCTest).
