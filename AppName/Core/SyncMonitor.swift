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
@MainActor
@Observable
final class SyncMonitor {
    private(set) var state: SyncState = .idle
    private(set) var lastSync: Date?
    /// Whether the first CloudKit import has finished. Lets a screen tell "new and
    /// empty" apart from "empty because the first sync has not landed yet".
    private(set) var hasCompletedFirstImport = false

    private var activePhases: Set<CloudSyncEvent.Kind> = []
    private var lastErrorMessage: String?

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
            activePhases.insert(event.kind)
        } else {
            activePhases.remove(event.kind)
            if event.errorDescription == nil {
                lastSync = Date()
                if event.kind == .importData { hasCompletedFirstImport = true }
            }
        }
        lastErrorMessage = event.errorDescription
        recomputeState()
    }

    /// Surface a store-load failure that would otherwise be swallowed at startup.
    func report(storeLoadError: Error) {
        lastErrorMessage = SyncErrorMapper.describe(storeLoadError).message
        recomputeState()
    }

    private func recomputeState() {
        if let message = lastErrorMessage {
            state = .error(message: message)
        } else if !activePhases.isEmpty {
            state = .syncing
        } else {
            state = .idle
        }
    }
}
