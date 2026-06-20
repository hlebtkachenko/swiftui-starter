# ADR-0008: In-app search

**Status:** Accepted - 2026-06-09

## Context

AppName needs to find items and lists quickly. Core Data has no built-in full-text engine, and the data is mirrored to CloudKit, which rules out reaching under Core Data into raw SQLite features.

## Decision

- Do structured filtering and sorting with Core Data predicates and indexes.
- Do text search with Core Spotlight: index objects through `NSCoreDataCoreSpotlightDelegate` and query with `CSSearchQuery`, which also makes content discoverable from system Spotlight and Siri.
- Do not use raw SQLite FTS5; it conflicts with the CloudKit mirroring.

## Consequences

- Search is zero-dependency, native, and integrated with the OS for free.
- Core Spotlight adds a small indexing write path alongside saves; an acceptable cost.
- Implementation (verified 2026-06-09): attach `NSCoreDataCoreSpotlightDelegate` to the store description with persistent history enabled and call `startSpotlightIndexing()`; it works through `NSPersistentCloudKitContainer` (a subclass). Use `CSUserQuery` for the in-app search bar (it adds suggestions) and `CSSearchQuery` for background queries.
- Later enhancement, not v1: `SpotlightSearchTool`, which exposes the Spotlight index to a Foundation Models session, is iOS 27.0 beta, above our floor.

## Links

- Evidence: research report section 5 (local query engine).
- Related: [ADR-0010](0010-on-device-ai-posture.md) builds semantic search on the same local store.
