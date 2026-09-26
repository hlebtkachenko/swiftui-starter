import CoreData
import CloudKit

/// Core Data-backed `AppNameStore`. Maps `NSManagedObject`s to and from the
/// Sendable domain structs so callers never see Core Data. It operates on a
/// single context: the view context for the app, an in-memory context for tests
/// and previews (ADR-0013).
final class CoreDataAppNameStore: AppNameStore {
    private let context: NSManagedObjectContext
    private let container: NSPersistentCloudKitContainer?

    init(context: NSManagedObjectContext, container: NSPersistentCloudKitContainer? = nil) {
        self.context = context
        self.container = container
    }

    convenience init(_ persistence: PersistenceController) {
        self.init(context: persistence.container.viewContext, container: persistence.container)
    }

    // MARK: Wishlists

    func wishlists() throws -> [Wishlist] {
        try context.fetch(WishlistMO.fetchAllRequest()).map(Self.map)
    }

    @discardableResult
    func createWishlist(title: String) throws -> Wishlist {
        let mo = WishlistMO(context: context)
        mo.id = UUID()
        mo.title = title
        mo.createdAt = Date()
        try save()
        return Self.map(mo)
    }

    func deleteWishlist(id: UUID) throws {
        guard let mo = try fetchWishlist(id) else { throw AppNameStoreError.wishlistNotFound(id) }
        try delete([mo])
    }

    // MARK: Items

    func items(in wishlistID: UUID) throws -> [WishItem] {
        let request = NSFetchRequest<WishItemMO>(entityName: AppNameModel.Entity.wishItem)
        request.predicate = NSPredicate(format: "wishlist.id == %@", wishlistID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return try context.fetch(request).map(Self.map)
    }

    @discardableResult
    func addItem(to wishlistID: UUID, title: String, note: String?, url: URL?) throws -> WishItem {
        guard let list = try fetchWishlist(wishlistID) else { throw AppNameStoreError.wishlistNotFound(wishlistID) }
        let mo = WishItemMO(context: context)
        mo.id = UUID()
        mo.title = title
        mo.note = note
        mo.urlString = url?.absoluteString
        mo.createdAt = Date()
        mo.wishlist = list
        try save()
        return Self.map(mo)
    }

    func deleteItem(id: UUID) throws {
        guard let mo = try fetchItem(id) else { throw AppNameStoreError.itemNotFound(id) }
        try delete([mo])
    }

    // MARK: Objects shown by the views

    /// Delete objects the views already hold, by identity rather than by `id`.
    func delete(_ objects: [NSManagedObject]) throws {
        objects.forEach(context.delete)
        try save()
    }

    /// Whether the user may change this object: `false` on a share they joined
    /// read-only. Always `true` without CloudKit.
    func canUpdate(_ object: NSManagedObject) -> Bool {
        container?.canUpdateRecord(forManagedObjectWith: object.objectID) ?? true
    }

    func canDelete(_ object: NSManagedObject) -> Bool {
        container?.canDeleteRecord(forManagedObjectWith: object.objectID) ?? true
    }

    // MARK: Saving and fetching

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

    private func fetchWishlist(_ id: UUID) throws -> WishlistMO? {
        try first(WishlistMO.self, entity: AppNameModel.Entity.wishlist, where: NSPredicate(format: "id == %@", id as CVarArg))
    }

    private func fetchItem(_ id: UUID) throws -> WishItemMO? {
        try first(WishItemMO.self, entity: AppNameModel.Entity.wishItem, where: NSPredicate(format: "id == %@", id as CVarArg))
    }

    private func first<T: NSManagedObject>(_ type: T.Type, entity: String, where predicate: NSPredicate) throws -> T? {
        let request = NSFetchRequest<T>(entityName: entity)
        request.predicate = predicate
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    // MARK: Mapping

    private static func map(_ mo: WishlistMO) -> Wishlist {
        Wishlist(id: mo.id ?? UUID(), title: mo.title ?? "", createdAt: mo.createdAt ?? .distantPast)
    }

    private static func map(_ mo: WishItemMO) -> WishItem {
        WishItem(id: mo.id ?? UUID(),
                 wishlistID: mo.wishlist?.id ?? UUID(),
                 title: mo.title ?? "",
                 note: mo.note,
                 url: mo.urlString.flatMap { URL(string: $0) },
                 createdAt: mo.createdAt ?? .distantPast)
    }
}

// MARK: - Family sharing (CKShare)

/// CloudKit-backed sharing over `NSPersistentCloudKitContainer`. These calls need
/// a provisioned container and an iCloud account, so they run on device, not in
/// headless tests. They throw `cloudKitUnavailable` when the store has no
/// container (the in-memory test double).
extension CoreDataAppNameStore {
    /// Create a `CKShare` over a wishlist's hierarchy.
    func shareWishlist(id: UUID) async throws -> CKShare {
        guard let container else { throw AppNameStoreError.cloudKitUnavailable }
        guard let list = try fetchWishlist(id) else { throw AppNameStoreError.wishlistNotFound(id) }
        let (_, share, _) = try await container.share([list], to: nil)
        share[CKShare.SystemFieldKey.title] = (list.title ?? "") as CKRecordValue
        return share
    }

    /// What `ShareLink` needs for a wishlist: its existing share, or a handler that
    /// creates one. `nil` while sync is off, since there is no container to share in.
    func shareItem(forWishlist id: UUID) throws -> CloudShareItem? {
        guard let identifier = PersistenceController.cloudKitContainerIdentifier else { return nil }
        return CloudShareItem(container: CKContainer(identifier: identifier),
                              existing: try existingShare(forWishlist: id)) { [self] in
            try await shareWishlist(id: id)
        }
    }

    /// The existing share for a wishlist, if it is already shared.
    func existingShare(forWishlist id: UUID) throws -> CKShare? {
        guard let container else { throw AppNameStoreError.cloudKitUnavailable }
        guard let list = try fetchWishlist(id) else { throw AppNameStoreError.wishlistNotFound(id) }
        return try container.fetchShares(matching: [list.objectID])[list.objectID]
    }

    /// Accept an invitation received from the system share flow.
    func acceptShare(_ metadata: CKShare.Metadata) async throws {
        guard let container, let store = sharedStore(container) else {
            throw AppNameStoreError.cloudKitUnavailable
        }
        _ = try await container.acceptShareInvitations(from: [metadata], into: store)
    }

    /// The `.shared`-scope persistent store that accepted shares land in (matched
    /// by file name).
    private func sharedStore(_ container: NSPersistentCloudKitContainer) -> NSPersistentStore? {
        container.persistentStoreCoordinator.persistentStores.first {
            $0.url?.lastPathComponent == PersistenceController.sharedStoreFileName
        }
    }
}
