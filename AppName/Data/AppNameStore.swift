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

/// Where a giver is in the act of giving.
enum ClaimStatus: Int16, Sendable, CaseIterable {
    case considering
    case claimed
    case purchased
}

/// A giver's claim on an item. Kept off the owner-visible item record so the
/// wishlist owner never sees a spoiler (ADR-0006). The `itemID` is a loose
/// reference, deliberately not a Core Data relationship, so a claim never joins
/// the item's shared object graph and can live in a separate giver-only
/// store/share/zone.
struct GiftClaim: Identifiable, Sendable, Equatable {
    let id: UUID
    let itemID: UUID
    var claimedBy: String
    var status: ClaimStatus
    var claimedAt: Date
}

/// The persistence/sync port. App logic depends on this protocol, not on Core
/// Data or CloudKit, so the same logic runs against an in-memory store in
/// headless tests and against `NSPersistentCloudKitContainer` at runtime
/// (ADR-0005, ADR-0013).
@MainActor
protocol AppNameStore {
    // Wishlists and items (owner-visible, family-shared content).
    func wishlists() throws -> [Wishlist]
    @discardableResult func createWishlist(title: String) throws -> Wishlist
    func deleteWishlist(id: UUID) throws
    func items(in wishlistID: UUID) throws -> [WishItem]
    @discardableResult func addItem(to wishlistID: UUID, title: String, note: String?, url: URL?) throws -> WishItem
    func deleteItem(id: UUID) throws

    // Gift claims (the giver-only partition).
    @discardableResult func setClaim(itemID: UUID, by participant: String, status: ClaimStatus) throws -> GiftClaim
    func removeClaim(itemID: UUID, by participant: String) throws
    /// Every claim recorded for an item. In production the wishlist owner is not
    /// a participant of the claims zone and so has none of these rows locally.
    func claims(forItem itemID: UUID) throws -> [GiftClaim]
}

extension AppNameStore {
    /// Claims a viewer is allowed to see. The wishlist owner sees none, which
    /// preserves the surprise (ADR-0006). This encodes the partition rule for
    /// callers and tests even before CloudKit zone separation is wired.
    func visibleClaims(forItem itemID: UUID, viewerIsOwner: Bool) throws -> [GiftClaim] {
        viewerIsOwner ? [] : try claims(forItem: itemID)
    }
}

enum AppNameStoreError: Error, Equatable {
    case wishlistNotFound(UUID)
    case itemNotFound(UUID)
    case cloudKitUnavailable
}
