import Testing
import Foundation
import CoreData
import CloudKit
@testable import AppName

/// Store tests run against an in-memory Core Data store, headless and with no
/// CloudKit (ADR-0013). Each test builds its own in-memory stack.
@MainActor
struct AppNameStoreTests {
    private func makeStore() -> (AppNameStore, NSManagedObjectContext) {
        let context = PersistenceController(inMemory: true).container.viewContext
        return (AppNameStore(context: context), context)
    }

    @Test func createsAndFetchesFolders() throws {
        let (store, context) = makeStore()
        try store.createFolder(title: "Inbox")
        let folders = try context.fetch(Folder.sortedFetchRequest())
        #expect(folders.map(\.title) == ["Inbox"])
        #expect(folders.first?.createdAt != nil)
    }

    @Test func itemsAreSortedByCreation() throws {
        let (store, context) = makeStore()
        let folder = try store.createFolder(title: "Inbox")
        try store.createItem(in: folder, title: "First")
        try store.createItem(in: folder, title: "Second")
        let items = try context.fetch(Item.sortedFetchRequest(in: folder))
        #expect(items.map(\.title) == ["First", "Second"])
    }

    @Test func deletingAFolderDeletesItsItems() throws {
        let (store, context) = makeStore()
        let folder = try store.createFolder(title: "Temp")
        try store.createItem(in: folder, title: "Thing")
        try store.delete(folder)
        #expect(try context.count(for: Folder.sortedFetchRequest()) == 0)
        #expect(try context.count(for: NSFetchRequest<Item>(entityName: AppNameModel.Entity.item)) == 0)
    }

    @Test func failedSaveRollsBack() throws {
        let context = FailingSaveContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = PersistenceController(inMemory: true).container.persistentStoreCoordinator
        let store = AppNameStore(context: context)
        #expect(throws: CocoaError.self) { try store.createFolder(title: "Lost") }
        #expect(context.hasChanges == false)
        #expect(context.registeredObjects.isEmpty)
    }

    @Test func localObjectsAreEditable() throws {
        let controller = PersistenceController(inMemory: true)
        let store = AppNameStore(controller)
        let folder = try store.createFolder(title: "Mine")
        #expect(store.canEdit(folder))
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
}

/// The in-memory-store sharing guard. Headless: no CloudKit network, no iCloud account.
@MainActor
struct SharingTests {
    @Test func sharingIsUnavailableOnTheInMemoryStore() throws {
        let store = AppNameStore(context: PersistenceController(inMemory: true).container.viewContext)
        let folder = try store.createFolder(title: "Shared")
        #expect(throws: AppNameStoreError.cloudKitUnavailable) {
            _ = try store.existingShare(for: folder)
        }
    }

    @Test func noShareItemWhileSyncIsOff() throws {
        let store = AppNameStore(PersistenceController(inMemory: true))
        let folder = try store.createFolder(title: "Local")
        #expect(try store.shareItem(for: folder) == nil)
    }
}

/// A context whose save fails with an ordinary error, to exercise rollback.
/// Swift requires restating the `@unchecked Sendable` it inherits from the SDK.
nonisolated private final class FailingSaveContext: NSManagedObjectContext, @unchecked Sendable {
    override func save() throws { throw CocoaError(.validationMultipleErrors) }
}
