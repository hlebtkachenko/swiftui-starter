import CoreData

// `NSManagedObject` subclasses for the programmatic model. The view layer reads
// these directly with `@FetchRequest` (ADR-0003); the store maps them to and
// from the Sendable domain structs so logic stays Core Data-free.

final class WishlistMO: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var title: String?
    @NSManaged var createdAt: Date?
    @NSManaged var items: NSSet?

    /// Non-optional identity for SwiftUI `ForEach` / `List` selection.
    var listID: UUID { id ?? UUID() }

    static func fetchAllRequest() -> NSFetchRequest<WishlistMO> {
        let request = NSFetchRequest<WishlistMO>(entityName: AppNameModel.Entity.wishlist)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return request
    }
}

final class WishItemMO: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var title: String?
    @NSManaged var note: String?
    @NSManaged var urlString: String?
    @NSManaged var createdAt: Date?
    @NSManaged var wishlist: WishlistMO?

    var itemID: UUID { id ?? UUID() }
}

final class GiftClaimMO: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var itemID: UUID?
    @NSManaged var claimedBy: String?
    @NSManaged var statusRaw: Int16
    @NSManaged var claimedAt: Date?
}
