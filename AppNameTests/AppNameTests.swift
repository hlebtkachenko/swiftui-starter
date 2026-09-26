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

/// The in-memory-store sharing guard. Headless: no CloudKit network, no iCloud account.
@MainActor
struct FamilySharingTests {
    @Test func sharingIsUnavailableOnTheInMemoryStore() async {
        let store = CoreDataAppNameStore(context: PersistenceController(inMemory: true).container.viewContext)
        await #expect(throws: AppNameStoreError.cloudKitUnavailable) {
            _ = try await store.shareWishlist(id: UUID())
        }
    }
}
