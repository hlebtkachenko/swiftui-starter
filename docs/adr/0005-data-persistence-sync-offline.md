# ADR-0005: Data, persistence, sync, and offline

**Status:** Accepted - 2026-06-09; amended 2026-09-26 (generic context, App Group per app); amended 2026-09-27 (schema evolution, merge-policy tests)

## Context

An app built from this template that shares data between people needs three things at once: real cross-person sharing, dependable offline use, and private storage with no server to run. SwiftData on the private database syncs only one person's own devices and cannot share between people, so the shared layer must be Core Data.

## Decision

- Treat the local Core Data store (SQLite) as the single source of truth and the query engine; all reads, writes, and search run locally.
- Use CloudKit purely as the sync transport, never as a query layer: mirror with `NSPersistentCloudKitContainer` across a user's own devices (private database) and into participant views (shared database). Encrypt sensitive fields with `encryptedValues`.
- Rely on offline-first behavior that falls out of this design: edits apply locally and queue, then sync when connectivity returns. `NSPersistentCloudKitContainer` resolves field-level conflicts last-writer-wins; domain conflicts need app logic. Surface connectivity with `NWPathMonitor`.

## Consequences

- No server to operate or pay for; storage sits on each user's iCloud quota.
- Sync is near-realtime (CloudKit push within seconds to minutes), which AppName accepts because it needs no sub-second collaboration. True live presence or co-editing would require a custom server and is deliberately out of scope.
- CloudKit mirroring constrains the model: no unique attributes, relationships must be optional, and no deny delete rule.
- Re-verified against Apple's docs on 2026-06-09: SwiftData still cannot share cross-person (its `CloudKitDatabase` offers only `.automatic` / `.private` / `.none`), so Core Data stays the sharing layer, matching Apple's "Sharing Core Data objects between iCloud users" sample.
- App Group container: the template ships without one. Each app decides before its first external build whether a widget, extension, or App Clip will need the store; if so, move the store into an App Group container then, while no user data has to migrate (Apple's Backyard Birds widget reuses the data layer this way). `REGISTER_APP_GROUPS = YES` stays as the Xcode template default; it has no effect without the entitlement.
- Once the CloudKit schema is promoted to Production, synced schema changes are additive only: never rename or delete an entity, attribute, or relationship, and never change an attribute's type; add a new field and migrate data in code instead. New attributes must be optional or have a default. The view context's merge policy (`mergeByPropertyObjectTrump`: unsaved local edits win per property over store changes such as a CloudKit import) is pinned by unit tests; CloudKit's own cross-device resolution is unchanged.

## Links

- Evidence: research report section 5 (data, persistence, sync).
- Related: [ADR-0006](0006-sharing-access-control-roles.md), [ADR-0007](0007-file-attachment-storage.md), [ADR-0009](0009-notifications.md).
