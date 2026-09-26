import Foundation

// Domain value types that cross the persistence boundary. They are `Sendable`
// and free of Core Data, so app logic and headless tests never touch
// `NSManagedObject` (ADR-0013).

/// A shared family list. The shareable root of the owner-visible content.
struct Wishlist: Identifiable, Sendable, Equatable {
    let id: UUID
    var title: String
    var createdAt: Date
}

/// An item on a wishlist. Owner-visible, family-shared content.
struct WishItem: Identifiable, Sendable, Equatable {
    let id: UUID
    var wishlistID: UUID
    var title: String
    var note: String?
    var url: URL?
    var createdAt: Date
}

/// The persistence/sync port. App logic depends on this protocol, not on Core
/// Data or CloudKit, so the same logic runs against an in-memory store in
/// headless tests and against `NSPersistentCloudKitContainer` at runtime
/// (ADR-0005, ADR-0013).
@MainActor
protocol AppNameStore {
    func wishlists() throws -> [Wishlist]
    @discardableResult func createWishlist(title: String) throws -> Wishlist
    func deleteWishlist(id: UUID) throws
    func items(in wishlistID: UUID) throws -> [WishItem]
    @discardableResult func addItem(to wishlistID: UUID, title: String, note: String?, url: URL?) throws -> WishItem
    func deleteItem(id: UUID) throws
}

enum AppNameStoreError: Error, Equatable {
    case wishlistNotFound(UUID)
    case itemNotFound(UUID)
    case cloudKitUnavailable
}
