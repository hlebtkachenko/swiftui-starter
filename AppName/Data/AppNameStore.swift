import CloudKit
import CoreData

/// The app's writes and CloudKit sharing over one context: the view context for
/// the app, an in-memory context for tests and previews (ADR-0013). Views read
/// through `@FetchRequest`; every write goes through here so a failed save is
/// rolled back.
final class AppNameStore {
    private let context: NSManagedObjectContext
    private let container: NSPersistentCloudKitContainer?

    init(context: NSManagedObjectContext, container: NSPersistentCloudKitContainer? = nil) {
        self.context = context
        self.container = container
    }

    convenience init(_ persistence: PersistenceController) {
        self.init(context: persistence.container.viewContext, container: persistence.container)
    }

    // MARK: Writes

    @discardableResult
    func createFolder(title: String) throws -> Folder {
        let folder = Folder(context: context)
        folder.title = title
        try save()
        return folder
    }

    @discardableResult
    func createItem(in folder: Folder, title: String) throws -> Item {
        let item = Item(context: context)
        item.title = title
        item.folder = folder
        try save()
        return item
    }

    func delete(_ object: NSManagedObject) throws {
        context.delete(object)
        try save()
    }

    /// Save, or roll back the unsaved changes and rethrow, so a failed write never
    /// lingers in the context to be retried by an unrelated later save.
    private func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Whether the user may change this object: `false` on a share they joined
    /// read-only. Always `true` without CloudKit.
    func canEdit(_ object: NSManagedObject) -> Bool {
        container?.canUpdateRecord(forManagedObjectWith: object.objectID) ?? true
    }

    /// Whether the user may delete this object. Always `true` without CloudKit.
    func canDelete(_ object: NSManagedObject) -> Bool {
        container?.canDeleteRecord(forManagedObjectWith: object.objectID) ?? true
    }

    // MARK: Sharing (CKShare)

    // These need a provisioned container and an iCloud account, so they run on
    // device, not in headless tests. They throw `cloudKitUnavailable` when the
    // store was built with `init(context:)` and so has no container.

    /// What `ShareLink` needs for a folder: its existing share, or a handler that
    /// creates one. `nil` while sync is off, since there is no container to share in.
    func shareItem(for folder: Folder) throws -> CloudShareItem? {
        guard let identifier = PersistenceController.cloudKitContainerIdentifier else { return nil }
        let folderID = folder.objectID
        return CloudShareItem(
            container: CKContainer(identifier: identifier),
            existing: try existingShare(for: folder)
        ) { [self] in
            try await share(folderID)
        }
    }

    /// The existing share for a folder, if it is already shared.
    func existingShare(for folder: Folder) throws -> CKShare? {
        guard let container else { throw AppNameStoreError.cloudKitUnavailable }
        return try container.fetchShares(matching: [folder.objectID])[folder.objectID]
    }

    /// Accept an invitation received from the system share flow.
    func acceptShare(_ metadata: CKShare.Metadata) async throws {
        guard let container, let store = sharedStore(container) else {
            throw AppNameStoreError.cloudKitUnavailable
        }
        _ = try await container.acceptShareInvitations(from: [metadata], into: store)
    }

    /// Create a `CKShare` over a folder and its items, titled after the folder. The
    /// share item may be stale by the time the sheet asks, and `share(_:to:)` fails
    /// for an already-shared object, so an existing share is returned first.
    private func share(_ folderID: NSManagedObjectID) async throws -> CKShare {
        guard let container else { throw AppNameStoreError.cloudKitUnavailable }
        if let existing = try container.fetchShares(matching: [folderID])[folderID] {
            return existing
        }
        let folder = try context.existingObject(with: folderID)
        let (_, share, _) = try await container.share([folder], to: nil)
        share[CKShare.SystemFieldKey.title] = ((folder as? Folder)?.title ?? "") as CKRecordValue
        return share
    }

    /// The `.shared`-scope persistent store that accepted shares land in (matched
    /// by file name).
    private func sharedStore(_ container: NSPersistentCloudKitContainer) -> NSPersistentStore? {
        container.persistentStoreCoordinator.persistentStores.first {
            $0.url?.lastPathComponent == PersistenceController.sharedStoreFileName
        }
    }
}

enum AppNameStoreError: Error, Equatable {
    case cloudKitUnavailable
}
