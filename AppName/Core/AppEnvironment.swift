import CloudKit
import CoreData
import MetricKit
import Observation
import OSLog
import SwiftUI

/// The composition root injected into every scene. Holds the spine the rest of
/// the app reads through the environment: the persistence/sync store and the
/// sync and connectivity monitors. Built once at
/// launch from a `PersistenceController`.
@Observable
final class AppEnvironment {
    /// The app's environment. The system delivers accepted shares to app and
    /// scene delegates that SwiftUI creates, so they reach the spine through this.
    static let shared = AppEnvironment(persistence: .shared)

    let persistence: PersistenceController
    let store: AppNameStore
    let sync: SyncMonitor
    let connectivity: Connectivity

    var viewContext: NSManagedObjectContext { persistence.container.viewContext }

    init(persistence: PersistenceController) {
        self.persistence = persistence
        self.store = AppNameStore(persistence)
        self.sync = SyncMonitor()
        self.connectivity = Connectivity(containerIdentifier: PersistenceController.cloudKitContainerIdentifier)

        // Surface a store-load failure that the controller no longer swallows.
        if let error = persistence.loadError {
            sync.report(storeLoadError: error)
        }
        // Subscribe to sync events now, before any window exists, so CloudKit
        // setup errors posted at launch are not lost.
        sync.start()
    }

    @ObservationIgnored private var started = false

    /// Start the remaining monitors. Every window calls this; only the first call runs.
    func start() {
        guard !started else { return }
        started = true
        connectivity.start()
        receiveMetrics()
        #if DEBUG
        seedSyncProbeIfRequested()
        #endif
    }

    /// Log MetricKit metric and diagnostic reports (ADR-0012). The system delivers
    /// at most one batch per day; first-party only, nothing leaves the device.
    private func receiveMetrics() {
        let metrics = MetricManager()
        Task {
            for await _ in metrics.metricReports { Log.app.info("MetricKit metric report received") }
        }
        Task {
            for await _ in metrics.diagnosticReports { Log.app.error("MetricKit diagnostic report received") }
        }
    }

    /// Run a store write from a view or command. The store has already rolled back
    /// a failed save; this records the failure instead of dropping it.
    func write(_ action: String, _ body: (AppNameStore) throws -> Void) {
        do {
            try body(store)
        } catch {
            Log.persistence.error("could not \(action, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Accept a share invitation into the shared store; a failure shows in the sync status.
    func acceptShare(_ metadata: CKShare.Metadata) {
        Log.sharing.notice("accepting CloudKit share")
        Task {
            do {
                try await store.acceptShare(metadata)
                Log.sharing.notice("CloudKit share accepted")
            } catch {
                Log.sharing.error("CloudKit share accept failed: \(error.localizedDescription, privacy: .public)")
                sync.report(error)
            }
        }
    }

    #if DEBUG
    /// Test-only affordance: when the app is launched with `-seedProbe <title>`,
    /// insert one folder with that title. Used to verify cross-device CloudKit
    /// sync from the command line (create on one device, observe it sync to
    /// another). Compiled out of Release builds.
    private func seedSyncProbeIfRequested() {
        guard let title = UserDefaults.standard.string(forKey: "seedProbe"), !title.isEmpty else { return }
        Log.app.notice("seeding sync probe folder: \(title, privacy: .public)")
        write("seed the sync probe") { try $0.createFolder(title: title) }
    }
    #endif

    /// The single status to show in chrome (see `SyncState.display`).
    var displayState: SyncState {
        SyncState.display(
            account: connectivity.account, isOnline: connectivity.isOnline,
            sync: sync.state, storeError: sync.storeLoadError)
    }
}
