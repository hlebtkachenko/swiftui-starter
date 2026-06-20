# ADR-0009: Notifications

**Status:** Accepted - 2026-06-09

## Context

Two distinct needs: keep devices in sync, and alert a person when something relevant happens (a member added or claimed something). With no push backend, both must run on Apple's infrastructure.

## Decision

- Drive background sync with silent APNs delivered through CloudKit subscriptions, set up automatically by `NSPersistentCloudKitContainer` with the remote-notifications background mode.
- Deliver user-facing alerts with a hybrid: configure `CKSubscription` alert notifications for events that must reach a person even when the app is closed, and use silent push plus on-device logic plus `UNUserNotificationCenter` local notifications for in-app freshness.

## Consequences

- Entirely first-party, no push server to run.
- Silent push is best-effort and throttled, so anything that must reach the user relies on the `CKSubscription` alert path, not on local notifications.

## Links

- Evidence: research report sections 5 and 8.
