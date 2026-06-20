# ADR-0003: UI and state architecture

**Status:** Accepted - 2026-06-09

## Context

Apple prescribes no app architecture (no MVVM, VIPER, or TCA), and Observation is its current state model. We want an idiomatic, testable structure without a heavy paradigm commitment.

## Decision

- Use the SwiftUI lifecycle (`App` / `Scene` / `WindowGroup`) with `NavigationSplitView` and `NavigationStack` for adaptive layout.
- Manage state with Observation: `@Observable` model and service types injected through `@Environment` or held with `@State`; views read and mutate them directly (the model-view, "MV", approach).
- Keep behavior in model/service types so it is unit-testable, and add a per-screen view model only when a screen genuinely earns one. Do not adopt TCA.
- Read persisted data through Core Data (see [ADR-0005](0005-data-persistence-sync-offline.md)) with `@FetchRequest` over `NSManagedObject`; SwiftData's `@Model`/`@Query` are not used. Reserve Observation `@Observable` for non-persistent app and service state.

## Consequences

- Minimal ceremony, idiomatic SwiftUI, and a logic core that tests cleanly.
- Without a prescribed structure, consistency is on us; the model/service split is the discipline that keeps it coherent.

## Links

- Evidence: research report sections 2 and 4 (app structure, architecture and state).
- Related: [ADR-0013](0013-testing-strategy.md) depends on logic living in testable model/service types.
