import CoreData
import Foundation
import Observation

/// Observes CloudKit mirroring and exposes a single `SyncState` for the UI.
///
/// It subscribes to `NSPersistentCloudKitContainer.eventChangedNotification` and
/// folds the raw setup/import/export events into idle / syncing / error. Account
/// and network conditions are owned by `Connectivity`; `AppEnvironment` composes
/// the two for display. The event stream is reduced to a `Sendable`
/// `CloudSyncEvent` at the boundary, so `ingest(_:)` is unit-testable without a
/// live container.
@Observable
final class SyncMonitor {
    private(set) var state: SyncState = .idle
    private(set) var lastSync: Date?
    /// A store-load failure. It outranks every sync event and nothing clears it.
    private(set) var storeLoadError: String?

    /// In-flight events, keyed by event identifier: the private and shared stores
    /// can run events of the same kind at once.
    private var activeEvents: Set<UUID> = []
    /// The last failed event's message; cleared only by an event that finishes OK.
    private var eventError: String?

    /// Begin observing the live event stream. Safe to call once at launch; with no
    /// CloudKit container (tests, previews) no events ever arrive and it stays idle.
    func start() {
        Task { [weak self] in
            let stream = NotificationCenter.default.notifications(
                named: NSPersistentCloudKitContainer.eventChangedNotification
            )
            for await note in stream {
                guard
                    let raw = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event
                else { continue }
                self?.ingest(CloudSyncEvent(raw))
            }
        }
    }

    /// Fold one event into the current state. Public for testing.
    func ingest(_ event: CloudSyncEvent) {
        if event.inProgress {
            activeEvents.insert(event.id)
        } else {
            activeEvents.remove(event.id)
            if let message = event.errorDescription {
                eventError = message
            } else {
                eventError = nil
                lastSync = Date()
            }
        }
        recomputeState()
    }

    /// Surface a store-load failure that would otherwise be swallowed at startup.
    func report(storeLoadError error: Error) {
        storeLoadError = SyncErrorMapper.describe(error)
        recomputeState()
    }

    /// Surface a one-off CloudKit failure (for example accepting a share). The
    /// next event that finishes cleanly clears it.
    func report(_ error: Error) {
        eventError = SyncErrorMapper.describe(error)
        recomputeState()
    }

    private func recomputeState() {
        if let message = storeLoadError ?? eventError {
            state = .error(message: message)
        } else if !activeEvents.isEmpty {
            state = .syncing
        } else {
            state = .idle
        }
    }
}
