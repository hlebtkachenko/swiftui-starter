# ADR-0007: File and attachment storage

**Status:** Accepted - 2026-06-09

## Context

AppName stores images and small files (gift photos and similar). With a pure-Apple stack and no server, the storage must travel with the synced data and respect the sharing model.

## Decision

- Store binaries as `CKAsset`, via the Core Data "Allows External Storage" attribute. Assets sit in the owning record's iCloud (the owner's quota) and are encrypted by default.
- Keep media modest and hold thumbnails locally; do not push large files. Use no external object store, bucket, or CDN.

## Consequences (including the deletion semantics)

- Deleting the app removes only the local copy; the iCloud data persists and re-syncs on reinstall. This holds whether the owner or a participant deletes the app.
- Participants never keep the shared data in their own iCloud; they hold a view of the owner's records.
- Data is permanently lost only when the owner deletes their iCloud account or data, or when in-app account deletion tears down the zone, which removes it for everyone. This is exactly why [ADR-0006](0006-sharing-access-control-roles.md) surfaces the owner as admin and [ADR-0011](0011-auth-account-lifecycle.md) designs ownership teardown.

## Links

- Evidence: research report section 5 (encryption, assets, sharing shape).
