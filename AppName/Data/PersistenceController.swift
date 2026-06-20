import CoreData
import CloudKit
import OSLog

/// Builds the Core Data stack. `shared` uses `NSPersistentCloudKitContainer`;
/// `inMemory` uses an ephemeral store with no CloudKit, which is the headless
/// test and preview double (ADR-0013).
///
/// The gift-claim partition (ADR-0006) is enforced by the model (a claim
/// references its item by UUID, never by relationship) and by the visibility rule
/// on `AppNameStore`. The physical CloudKit zone/share separation that excludes the
/// wishlist owner is a follow-up; for now a single store carries every entity.
@MainActor
final class PersistenceController {
    let container: NSPersistentCloudKitContainer

    /// The error from `loadPersistentStores`, if any. Kept (not swallowed) so the
    /// spine can surface a real startup failure through `SyncMonitor` instead of
    /// the app silently running with no store. `nil` on a clean load.
    private(set) var loadError: Error?

    /// The provisioned CloudKit container that backs sync and `CKShare`. `nil`
    /// runs the app as a pure local store, which is the template default so a
    /// fresh clone launches without any iCloud setup.
    ///
    /// To turn sync on: create the container in the Apple Developer portal, set
    /// its identifier in `AppName.entitlements` and `Info.plist`, then set this to
    /// that identifier (for example `"iCloud.dev.hapd.appname"`). It must stay
    /// `nil` until the container exists, because activating CloudKit against an
    /// unprovisioned container hard-crashes on launch (an uncatchable trap on
    /// `com.apple.coredata.cloudkit.queue`). A run target with no signed-in iCloud
    /// account does not crash — `loadPersistentStores` logs and the store stays
    /// local until an account appears.
    static let cloudKitContainerIdentifier: String? = nil

    /// File name of the second persistent store that holds wishlists shared *to*
    /// this user by others. CloudKit requires a dedicated `.shared`-scope store to
    /// receive a `CKShare` participation; the user's own wishlists stay in the
    /// `.private`-scope default store.
    static let sharedStoreFileName = "shared.sqlite"

    static let shared = PersistenceController(inMemory: false)

    /// An in-memory controller pre-populated with deterministic sample data, for
    /// SwiftUI previews.
    static func preview() -> PersistenceController {
        let controller = PersistenceController(inMemory: true)
        try? SampleData.populate(controller.container.viewContext)
        return controller
    }

    init(inMemory: Bool) {
        container = NSPersistentCloudKitContainer(name: "AppName", managedObjectModel: AppNameModel.make())

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("NSPersistentContainer has no default store description")
        }
        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
            description.cloudKitContainerOptions = nil
        } else {
            // History tracking and remote-change notifications are prerequisites
            // for CloudKit mirroring and Core Spotlight indexing.
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            if let identifier = Self.cloudKitContainerIdentifier {
                // Private-scope store: the user's own wishlists.
                let privateOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: identifier)
                privateOptions.databaseScope = .private
                description.cloudKitContainerOptions = privateOptions

                // Shared-scope store: wishlists shared *to* this user land here once
                // their CKShare invitation is accepted. Same model and configuration
                // as the private store (only the database scope differs), which is the
                // supported sharing setup — unlike the configuration-scoped split that
                // crashed v0.1.4.
                guard let sharedDescription = description.copy() as? NSPersistentStoreDescription,
                      let privateURL = description.url else {
                    fatalError("Could not derive the shared store description")
                }
                sharedDescription.url = privateURL
                    .deletingLastPathComponent()
                    .appendingPathComponent(Self.sharedStoreFileName)
                let sharedOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: identifier)
                sharedOptions.databaseScope = .shared
                sharedDescription.cloudKitContainerOptions = sharedOptions

                container.persistentStoreDescriptions = [description, sharedDescription]
            }
        }

        container.loadPersistentStores { [self] _, error in
            // Do not crash on a store/CloudKit setup problem (no iCloud account,
            // an unprovisioned container, a Keychain reset). Record and continue
            // with whatever loaded; `SyncMonitor` surfaces it and sync resumes once
            // the environment is valid. The handler runs synchronously for the
            // SQLite and in-memory stores used here, so `loadError` is set by the
            // time `init` returns.
            if let error {
                loadError = error
                Log.persistence.error("persistent store load issue: \(error.localizedDescription, privacy: .public)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }
}
