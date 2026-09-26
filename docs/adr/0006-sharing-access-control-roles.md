# ADR-0006: Sharing, access control, and roles

**Status:** Accepted - 2026-06-09; amended 2026-09-26 (generic example, gift-claim partition removed)

## Context

Participants in a shared collection must see only what was shared with them and must never reach anyone else's records. They also need to understand who holds the data, because in CloudKit the shared content lives in the owner's iCloud.

## Decision

- Lean entirely on CloudKit's server-enforced access control; write no authorization layer of our own. The private database is the user's alone; a `CKShare` over a record hierarchy (a root object and its children; template: `Folder` / `Item`) grants access only to invited participants, each as read-only or read-write.
- Map each shared root object to a share plus its custom record zone; the participant set is the group. A member of one share cannot reach another share unless invited.
- Surface the share owner from the `CKShare` participant role when an app shows a members list, so participants can see who holds the data, and gate edits on the participant's permission (`canUpdateRecord(forManagedObjectWith:)`).

## Consequences

- Strong, audited isolation with no custom access-control code to get wrong.
- The owner-leaves case becomes the resilience risk this surfaces; see [ADR-0007](0007-file-attachment-storage.md) and [ADR-0011](0011-auth-account-lifecycle.md).
- Schema constraints from Apple's sharing model (verified 2026-06-09): sharing an object moves its whole object graph into the share's zone, and objects belonging to different shares cannot be related, so objects in different shares must not hold direct Core Data relationships to each other.
- Funnel shared content into a few shares (for example one per group of people) with an "add to existing share" path, since CloudKit limits zones per database.
- Implementation, verified on device before this template was extracted: receiving a share requires a dedicated `.shared`-scope persistent store paired with the `.private` one — a database-scope split, *not* a configuration-scoped split, which crashed in an earlier build. Acceptance is not hands-off on OS 26 and later as first assumed: for a SwiftUI (scene-based) app the metadata is delivered to the **scene delegate** (`scene(_:willConnectTo:)` on cold launch, `windowScene(_:userDidAcceptCloudKitShareWith:)` when warm) and not to the `UIApplicationDelegate`, and the app must declare `CKSharingSupported` so the system offers it as the share handler.
- The template now shares through a SwiftUI `ShareLink` (a `Transferable` share item that reuses an existing share before preparing a new one). Only the earlier `UICloudSharingController` path was verified on device; the `ShareLink` path is not yet device-verified.
- On-device checks pending: items added to a folder shared to the user land in the `.shared` store; the share title (the folder title) shows in the invitation; the `ShareLink` existing-share flow works across two iCloud accounts.

## Links

- Evidence: research report sections 5 and 8.7.
