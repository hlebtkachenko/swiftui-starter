import Testing
import Foundation
import CoreData
import CloudKit
@testable import AppName

/// Logic tests run against an in-memory Core Data store, headless and with no
/// CloudKit (ADR-0013). Serialized because the suites share an in-memory stack.
@MainActor
@Suite(.serialized)
struct AppNameStoreTests {
    private func makeStore() -> CoreDataAppNameStore {
        CoreDataAppNameStore(context: PersistenceController(inMemory: true).container.viewContext)
    }

    @Test func createsAndFetchesWishlists() throws {
        let store = makeStore()
        let list = try store.createWishlist(title: "Holiday")
        let all = try store.wishlists()
        #expect(all.count == 1)
        #expect(all.first?.id == list.id)
        #expect(all.first?.title == "Holiday")
    }

    @Test func addsItemsInInsertionOrder() throws {
        let store = makeStore()
        let list = try store.createWishlist(title: "Holiday")
        try store.addItem(to: list.id, title: "Scarf", note: "Blue", url: nil)
        try store.addItem(to: list.id, title: "Mug", note: nil, url: URL(string: "https://example.com"))
        let items = try store.items(in: list.id)
        #expect(items.map(\.title) == ["Scarf", "Mug"])
        #expect(items.first?.note == "Blue")
        #expect(items.last?.url == URL(string: "https://example.com"))
    }

    @Test func addingItemToMissingWishlistThrows() throws {
        let store = makeStore()
        #expect(throws: AppNameStoreError.self) {
            try store.addItem(to: UUID(), title: "x", note: nil, url: nil)
        }
    }

    @Test func giftClaimIsHiddenFromOwnerButVisibleToGivers() throws {
        let store = makeStore()
        let list = try store.createWishlist(title: "Birthday")
        let item = try store.addItem(to: list.id, title: "Headphones", note: nil, url: nil)
        try store.setClaim(itemID: item.id, by: "anna", status: .purchased)

        // The owner must never see the claim: spoiler protection (ADR-0006).
        #expect(try store.visibleClaims(forItem: item.id, viewerIsOwner: true).isEmpty)

        let giverView = try store.visibleClaims(forItem: item.id, viewerIsOwner: false)
        #expect(giverView.count == 1)
        #expect(giverView.first?.status == .purchased)
        #expect(giverView.first?.claimedBy == "anna")
    }

    @Test func claimIsUpsertedPerParticipant() throws {
        let store = makeStore()
        let list = try store.createWishlist(title: "Birthday")
        let item = try store.addItem(to: list.id, title: "Book", note: nil, url: nil)
        try store.setClaim(itemID: item.id, by: "anna", status: .considering)
        try store.setClaim(itemID: item.id, by: "anna", status: .claimed) // updates, not duplicates
        try store.setClaim(itemID: item.id, by: "ben", status: .considering) // different giver
        let claims = try store.claims(forItem: item.id)
        #expect(claims.count == 2)
        #expect(claims.first(where: { $0.claimedBy == "anna" })?.status == .claimed)
    }

    @Test func removingClaimLeavesOthers() throws {
        let store = makeStore()
        let list = try store.createWishlist(title: "Birthday")
        let item = try store.addItem(to: list.id, title: "Plant", note: nil, url: nil)
        try store.setClaim(itemID: item.id, by: "anna", status: .claimed)
        try store.setClaim(itemID: item.id, by: "ben", status: .considering)
        try store.removeClaim(itemID: item.id, by: "anna")
        let claims = try store.claims(forItem: item.id)
        #expect(claims.map(\.claimedBy) == ["ben"])
    }

    @Test func claimDoesNotAlterTheItemRecord() throws {
        // The partition: claims are a separate entity referenced by UUID, never a
        // relationship, so they never join the item's shared graph (ADR-0006).
        let store = makeStore()
        let list = try store.createWishlist(title: "Birthday")
        let item = try store.addItem(to: list.id, title: "Watch", note: nil, url: nil)
        try store.setClaim(itemID: item.id, by: "anna", status: .claimed)
        let refetched = try store.items(in: list.id)
        #expect(refetched.count == 1)
        #expect(refetched.first?.id == item.id)
    }

    @Test func deletingWishlistRemovesItsItems() throws {
        let store = makeStore()
        let list = try store.createWishlist(title: "Temp")
        try store.addItem(to: list.id, title: "Thing", note: nil, url: nil)
        try store.deleteWishlist(id: list.id)
        #expect(try store.wishlists().isEmpty)
        #expect(try store.items(in: list.id).isEmpty)
    }

    @Test func seedDataPopulatesPreviewStore() throws {
        let controller = PersistenceController(inMemory: true)
        try SampleData.populate(controller.container.viewContext)
        let store = CoreDataAppNameStore(context: controller.container.viewContext)
        #expect(try store.wishlists().count == 1)
        let items = try store.items(in: store.wishlists()[0].id)
        #expect(items.count == 2)
    }
}

/// Pure `CKShare` role/permission mapping (ADR-0006) and the
/// in-memory-store guard. Headless: no CloudKit network, no iCloud account.
@MainActor
struct FamilySharingMappingTests {
    @Test func shareOwnerMapsToAdmin() {
        #expect(FamilyRole(.owner) == .admin)
        #expect(FamilyRole(.privateUser) == .member)
        #expect(FamilyRole(.publicUser) == .member)
    }

    @Test func permissionMapping() {
        #expect(SharePermission(.readOnly) == .readOnly)
        #expect(SharePermission(.readWrite) == .readWrite)
        #expect(SharePermission(.none) == .unknown)
    }

    @Test func sharingIsUnavailableOnTheInMemoryStore() async {
        let store = CoreDataAppNameStore(context: PersistenceController(inMemory: true).container.viewContext)
        await #expect(throws: AppNameStoreError.cloudKitUnavailable) {
            _ = try await store.shareWishlist(id: UUID())
        }
    }
}
