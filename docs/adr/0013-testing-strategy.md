# ADR-0013: Testing strategy

**Status:** Accepted - 2026-06-09; amended 2026-09-26 (in-memory Core Data store as the double, no seed recipe)

## Context

Swift Testing is Apple's modern framework, and the app is largely agent-developed, which rewards a fast headless loop. CloudKit, however, has no headless test harness: real sharing needs signed builds and live iCloud accounts.

## Decision

- Write unit and logic tests with Swift Testing; keep XCTest only for UI automation (XCUITest) and performance.
- Test in two layers:
  1. Keep CloudKit calls inside the store and persistence types, and test the logic core against an in-memory Core Data store (`PersistenceController(inMemory: true)`, no CloudKit), which runs headless and deterministically and is the loop an agent can drive. No protocol wraps the store: one concrete class, one in-memory configuration.
  2. Verify CloudKit and `CKShare` integration on signed builds with real iCloud accounts, drive the Mac app through computer-control, and exercise sharing with a second iCloud account.

## Consequences

- Almost all behavior is covered by the fast layer; CloudKit and UI correctness remain device-and-account integration that is partly manual.
- Keeping CloudKit inside the store and persistence types is what makes this split work; views and the spine never call CloudKit directly, which reinforces [ADR-0003](0003-ui-state-architecture.md).
- Patterns (verified 2026-06-09): give each test its own in-memory store so suites can run in parallel; prefer `struct`/`actor` suites; parameterize over `CaseIterable` with `@Test(arguments:)`; assert throwing with `#expect(throws:)` / `#require(throws:)` (the former returns the error for follow-up checks); use `confirmation()` for async callbacks; and use exit tests (`#expect(processExitsWith:)`) to cover model `precondition`/`fatalError` guards.
- Previews use the same in-memory store and create their objects through the store; the template ships no seed data (see `docs/patterns.md`).

## Links

- Evidence: research report section 3.1 (Swift Testing vs XCTest).
