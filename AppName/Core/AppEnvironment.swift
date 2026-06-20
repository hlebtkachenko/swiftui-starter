import CoreData
import Observation
import OSLog
import SwiftUI

/// The composition root injected into every scene. Holds the spine the rest of
/// the app reads through the environment: the persistence/sync store, the
/// navigation router, and the sync and connectivity monitors. Built once at
/// launch from a `PersistenceController`.
@MainActor
@Observable
final class AppEnvironment {
    let persistence: PersistenceController
    let store: CoreDataAppNameStore
    let router: AppRouter
    let sync: SyncMonitor
    let connectivity: Connectivity

    var viewContext: NSManagedObjectContext { persistence.container.viewContext }

    init(persistence: PersistenceController) {
        self.persistence = persistence
        self.store = CoreDataAppNameStore(persistence)
        self.router = AppRouter()
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
        #if os(iOS)
        MetricsSubscriber.shared.startReceiving()
        #endif
        #if DEBUG
        seedSyncProbeIfRequested()
        #endif
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

    /// The single status to show in chrome, composed from account, network, and
    /// sync. Account and offline take precedence over raw sync progress.
    var displayState: SyncState {
        if connectivity.account != .available {
            return .accountUnavailable(reason: connectivity.account.label)
        }
        if !connectivity.isOnline {
            return .offline
        }
        return sync.state
    }
}
