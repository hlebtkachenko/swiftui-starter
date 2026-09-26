import Testing
import Foundation
import CoreData
import CloudKit
@testable import AppName

/// Logic tests run against an in-memory Core Data store, headless and with no
/// CloudKit (ADR-0013). Each test builds its own in-memory stack.
@MainActor
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

    @Test func deletingAnItemLeavesTheRest() throws {
        let store = makeStore()
        let list = try store.createWishlist(title: "Temp")
        let first = try store.addItem(to: list.id, title: "One", note: nil, url: nil)
        try store.addItem(to: list.id, title: "Two", note: nil, url: nil)
        try store.deleteItem(id: first.id)
        #expect(try store.items(in: list.id).map(\.title) == ["Two"])
    }

    @Test func failedSaveRollsBack() throws {
        let context = FailingSaveContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = PersistenceController(inMemory: true).container.persistentStoreCoordinator
        let store = CoreDataAppNameStore(context: context)
        #expect(throws: CocoaError.self) { try store.createWishlist(title: "Lost") }
        #expect(context.hasChanges == false)
        #expect(context.registeredObjects.isEmpty)
    }

    @Test func localObjectsAreEditable() throws {
        let controller = PersistenceController(inMemory: true)
        let store = CoreDataAppNameStore(controller)
        try store.createWishlist(title: "Mine")
        let list = try #require(try controller.container.viewContext.fetch(WishlistMO.fetchAllRequest()).first)
        #expect(store.canUpdate(list))
        #expect(store.canDelete(list))
    }

    @Test func modelFollowsCloudKitRules() {
        // NSPersistentCloudKitContainer mirroring rules (ADR-0005).
        let model = PersistenceController(inMemory: true).container.managedObjectModel
        for entity in model.entities {
            #expect(entity.uniquenessConstraints.isEmpty, "\(entity.name ?? "?") has a unique constraint")
            for (name, attribute) in entity.attributesByName {
                #expect(attribute.isOptional || attribute.defaultValue != nil, "\(name) is required with no default")
            }
            for (name, relationship) in entity.relationshipsByName {
                #expect(relationship.isOptional, "\(name) is required")
                #expect(relationship.inverseRelationship != nil, "\(name) has no inverse")
                #expect(relationship.deleteRule != .denyDeleteRule, "\(name) uses Deny")
            }
        }
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

/// A context whose save fails with an ordinary error, to exercise rollback.
/// Swift requires restating the `@unchecked Sendable` it inherits from the SDK.
nonisolated private final class FailingSaveContext: NSManagedObjectContext, @unchecked Sendable {
    override func save() throws { throw CocoaError(.validationMultipleErrors) }
}
