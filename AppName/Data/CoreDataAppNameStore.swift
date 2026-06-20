import CoreData
import CloudKit

/// Core Data-backed `AppNameStore`. Maps `NSManagedObject`s to and from the
/// Sendable domain structs so callers never see Core Data. It operates on a
/// single context: the view context for the app, an in-memory context for tests
/// and previews (ADR-0013).
@MainActor
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
        try context.save()
        return Self.map(mo)
    }

    func deleteWishlist(id: UUID) throws {
        guard let mo = try fetchWishlist(id) else { throw AppNameStoreError.wishlistNotFound(id) }
        context.delete(mo)
        try context.save()
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
        try context.save()
        return Self.map(mo)
    }

    func deleteItem(id: UUID) throws {
        guard let mo = try fetchItem(id) else { throw AppNameStoreError.itemNotFound(id) }
        context.delete(mo)
        try context.save()
    }

    // MARK: Gift claims (partitioned)

    @discardableResult
    func setClaim(itemID: UUID, by participant: String, status: ClaimStatus) throws -> GiftClaim {
        let mo = try fetchClaim(itemID: itemID, participant: participant) ?? GiftClaimMO(context: context)
        if mo.id == nil { mo.id = UUID() }
        mo.itemID = itemID
        mo.claimedBy = participant
        mo.statusRaw = status.rawValue
        mo.claimedAt = Date()
        try context.save()
        return Self.map(mo)
    }

    func removeClaim(itemID: UUID, by participant: String) throws {
        guard let mo = try fetchClaim(itemID: itemID, participant: participant) else { return }
        context.delete(mo)
        try context.save()
    }

    func claims(forItem itemID: UUID) throws -> [GiftClaim] {
        let request = NSFetchRequest<GiftClaimMO>(entityName: AppNameModel.Entity.giftClaim)
        request.predicate = NSPredicate(format: "itemID == %@", itemID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "claimedAt", ascending: true)]
        return try context.fetch(request).map(Self.map)
    }

    // MARK: Fetch helpers

    private func fetchWishlist(_ id: UUID) throws -> WishlistMO? {
        try first(WishlistMO.self, entity: AppNameModel.Entity.wishlist, where: NSPredicate(format: "id == %@", id as CVarArg))
    }

    private func fetchItem(_ id: UUID) throws -> WishItemMO? {
        try first(WishItemMO.self, entity: AppNameModel.Entity.wishItem, where: NSPredicate(format: "id == %@", id as CVarArg))
    }

    private func fetchClaim(itemID: UUID, participant: String) throws -> GiftClaimMO? {
        try first(GiftClaimMO.self, entity: AppNameModel.Entity.giftClaim,
                  where: NSPredicate(format: "itemID == %@ AND claimedBy == %@", itemID as CVarArg, participant))
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

    private static func map(_ mo: GiftClaimMO) -> GiftClaim {
        GiftClaim(id: mo.id ?? UUID(),
                  itemID: mo.itemID ?? UUID(),
                  claimedBy: mo.claimedBy ?? "",
                  status: ClaimStatus(rawValue: mo.statusRaw) ?? .considering,
                  claimedAt: mo.claimedAt ?? .distantPast)
    }
}

// MARK: - Family sharing (CKShare)

/// CloudKit-backed sharing over `NSPersistentCloudKitContainer`. These calls need
/// a provisioned container and an iCloud account, so they run on device, not in
/// headless tests. They throw `cloudKitUnavailable` when the store has no
/// container (the in-memory test double).
extension CoreDataAppNameStore: AppNameFamilySharing {
    func shareWishlist(id: UUID) async throws -> CKShare {
        guard let container else { throw AppNameStoreError.cloudKitUnavailable }
        guard let list = try fetchWishlist(id) else { throw AppNameStoreError.wishlistNotFound(id) }
        let (_, share, _) = try await container.share([list], to: nil)
        return share
    }

    func existingShare(forWishlist id: UUID) throws -> CKShare? {
        guard let container else { throw AppNameStoreError.cloudKitUnavailable }
        guard let list = try fetchWishlist(id) else { throw AppNameStoreError.wishlistNotFound(id) }
        return try container.fetchShares(matching: [list.objectID])[list.objectID]
    }

    func members(forWishlist id: UUID) throws -> [FamilyMember] {
        guard let share = try existingShare(forWishlist: id) else { return [] }
        return share.participants.map(FamilyMember.init)
    }

    func acceptShare(_ metadata: CKShare.Metadata) async throws {
        guard let container, let store = sharedStore(container) else {
            throw AppNameStoreError.cloudKitUnavailable
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.acceptShareInvitations(from: [metadata], into: store) { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    /// The `.shared`-scope persistent store that accepted shares land in (matched
    /// by file name). The giver-only claims zone is a follow-up (ADR-0006).
    private func sharedStore(_ container: NSPersistentCloudKitContainer) -> NSPersistentStore? {
        container.persistentStoreCoordinator.persistentStores.first {
            $0.url?.lastPathComponent == PersistenceController.sharedStoreFileName
        }
    }
}
