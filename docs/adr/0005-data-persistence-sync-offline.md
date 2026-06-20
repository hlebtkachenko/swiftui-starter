# ADR-0005: Data, persistence, sync, and offline

**Status:** Accepted - 2026-06-09

## Context

A multi-user family app needs three things at once: real cross-person sharing, dependable offline use, and private storage with no server to run. SwiftData on the private database syncs only one person's own devices and cannot share between people, so the shared layer must be Core Data.

## Decision

- Treat the local Core Data store (SQLite) as the single source of truth and the query engine; all reads, writes, and search run locally.
- Use CloudKit purely as the sync transport, never as a query layer: mirror with `NSPersistentCloudKitContainer` across a user's own devices (private database) and into participant views (shared database). Encrypt sensitive fields with `encryptedValues`.
- Rely on offline-first behavior that falls out of this design: edits apply locally and queue, then sync when connectivity returns. `NSPersistentCloudKitContainer` resolves field-level conflicts last-writer-wins; domain conflicts need app logic. Surface connectivity with `NWPathMonitor`.

## Consequences

- No server to operate or pay for; storage sits on each user's iCloud quota.
- Sync is near-realtime (CloudKit push within seconds to minutes), which AppName accepts because it needs no sub-second collaboration. True live presence or co-editing would require a custom server and is deliberately out of scope.
- CloudKit mirroring constrains the model: no unique attributes, relationships must be optional, and no deny delete rule.
- Re-verified against Apple's docs on 2026-06-09: SwiftData still cannot share cross-person (its `CloudKitDatabase` offers only `.automatic` / `.private` / `.none`), so Core Data stays the sharing layer, matching Apple's "Sharing Core Data objects between iCloud users" sample.
- Implementation note: place the store in a shared App Group container from the start, so a future widget or App Clip can read it without a migration (Apple's Backyard Birds widget reuses the data layer through a shared container). See `docs/patterns.md`.

## Links

- Evidence: research report section 5 (data, persistence, sync).
- Related: [ADR-0006](0006-sharing-access-control-roles.md), [ADR-0007](0007-file-attachment-storage.md), [ADR-0009](0009-notifications.md).
