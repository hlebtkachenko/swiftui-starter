# ADR-0006: Sharing, access control, and family roles

**Status:** Accepted - 2026-06-09

## Context

Family members must see only their own family's data and must never reach another family's records. They also need to understand who holds the data, because in CloudKit the shared content lives in one person's iCloud.

## Decision

- Lean entirely on CloudKit's server-enforced access control; write no authorization layer of our own. The private database is the user's alone; a `CKShare` over a record hierarchy (a list and its items) grants access only to invited participants, each as read-only or read-write.
- Map a family/space to a share plus its custom record zone; the participant set is the group. A member of one share cannot reach another share unless invited.
- Present the family creator (the share owner) as **admin** in the members list, derived from the `CKShare` participant role, so members can see who holds the data.
- Partition gift-claim state so "claimed" never lands on an owner-visible shared record (it would spoil the surprise): keep it in a separate share/zone the owner is not in, or local to each giver. Settle this before building the schema.

## Consequences

- Strong, audited isolation with no custom access-control code to get wrong.
- The owner-leaves case becomes the resilience risk this surfaces; see [ADR-0007](0007-file-attachment-storage.md) and [ADR-0011](0011-auth-account-lifecycle.md).
- Claim-state partitioning is real modeling work and is hard to retrofit later.
- Schema constraints from Apple's sharing model (verified 2026-06-09): sharing an object moves its whole object graph into the share's zone, and objects belonging to different shares cannot be related, so per-family items must not hold direct Core Data relationships across families.
- Funnel shared content into a few shares (one per family group) with an "add to existing share" path, since CloudKit limits zones per database.
- Implementation, verified on device in v0.3.0: receiving a share requires a dedicated `.shared`-scope persistent store paired with the `.private` one — a database-scope split, *not* the configuration-scoped split that crashed v0.1.4. Acceptance is not hands-off on the OS 26 floor as first assumed: for a SwiftUI (scene-based) app the metadata is delivered to the **scene delegate** (`scene(_:willConnectTo:)` on cold launch, `windowScene(_:userDidAcceptCloudKitShareWith:)` when warm) and not to the `UIApplicationDelegate`, and the app must declare `CKSharingSupported` so the system offers it as the share handler. The current on-device share/accept surface is temporary scaffolding; the role-aware UI is a follow-up.

## Links

- Evidence: research report sections 5 and 8.7.
