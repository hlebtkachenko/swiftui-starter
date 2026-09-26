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
    let persistence: PersistenceController
    let store: CoreDataAppNameStore
    let sync: SyncMonitor
    let connectivity: Connectivity

    var viewContext: NSManagedObjectContext { persistence.container.viewContext }

    init(persistence: PersistenceController) {
        self.persistence = persistence
        self.store = CoreDataAppNameStore(persistence)
        self.sync = SyncMonitor()
        self.connectivity = Connectivity(containerIdentifier: PersistenceController.cloudKitContainerIdentifier)

        // Surface a store-load failure that the controller no longer swallows.
        if let error = persistence.loadError {
            sync.report(storeLoadError: error)
        }
    }

    /// Start the live monitors. Call once, after the first scene appears.
    func start() {
        sync.start()
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

    #if DEBUG
    /// Test-only affordance: when the app is launched with `-seedProbe <title>`,
    /// insert one wishlist with that title. Used to verify cross-device CloudKit
    /// sync from the command line (create on one device, observe it sync to
    /// another). Compiled out of Release builds.
    private func seedSyncProbeIfRequested() {
        guard let title = UserDefaults.standard.string(forKey: "seedProbe"), !title.isEmpty else { return }
        Log.app.notice("seeding sync probe wishlist: \(title, privacy: .public)")
        _ = try? store.createWishlist(title: title)
    }
    #endif

    /// The single status to show in chrome (see `SyncState.display`).
    var displayState: SyncState {
        SyncState.display(account: connectivity.account, isOnline: connectivity.isOnline,
                          sync: sync.state, storeError: sync.storeLoadError)
    }
}
