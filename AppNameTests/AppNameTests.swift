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

    // MARK: Merge policy (ADR-0005)

    /// A second, independent context on the same coordinator, standing in for a
    /// remote peer's context. Mirrors `failedSaveRollsBack`'s main-queue-context
    /// pattern rather than `newBackgroundContext()` to stay off another queue.
    private func makePeerContext(for controller: PersistenceController) -> NSManagedObjectContext {
        let peer = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        peer.persistentStoreCoordinator = controller.container.persistentStoreCoordinator
        return peer
    }

    @Test func viewContextUsesLastWriterWinsMergePolicy() {
        // Pins ADR-0005: field-level conflicts resolve by trumping the store with
        // whatever the in-memory object holds, not the whole object or the store.
        let controller = PersistenceController(inMemory: true)
        let policy = controller.container.viewContext.mergePolicy as? NSMergePolicy
        #expect(policy?.mergeType == .mergeByPropertyObjectTrumpMergePolicyType)
    }

    @Test func sameAttributeConflictKeepsTheViewContextsEdit() throws {
        let controller = PersistenceController(inMemory: true)
        let store = AppNameStore(controller)
        let viewContext = controller.container.viewContext
        let folder = try store.createFolder(title: "Mine")

        // Make the local edit first, without saving, so the view context's
        // save meets a stale snapshot.
        folder.title = "Local"

        let peer = makePeerContext(for: controller)
        let peerFolder = try #require(peer.object(with: folder.objectID) as? Folder)
        peerFolder.title = "Remote"
        try peer.save()

        // The automatic merge is queued, not applied, so the save below meets a
        // real conflict and goes through the merge policy.
        #expect(folder.committedValues(forKeys: ["title"])["title"] as? String == "Mine")

        try viewContext.save()

        let checkContext = makePeerContext(for: controller)
        let persisted = try #require(checkContext.object(with: folder.objectID) as? Folder)
        #expect(persisted.title == "Local")
    }

    @Test func differentAttributeConflictKeepsBothEdits() throws {
        let controller = PersistenceController(inMemory: true)
        let store = AppNameStore(controller)
        let viewContext = controller.container.viewContext
        let folder = try store.createFolder(title: "Mine")
        let fixedDate = Date(timeIntervalSince1970: 1_000_000)

        // Local edit to one attribute, unsaved, before the peer edits the other.
        folder.createdAt = fixedDate

        let peer = makePeerContext(for: controller)
        let peerFolder = try #require(peer.object(with: folder.objectID) as? Folder)
        peerFolder.title = "Remote"
        try peer.save()

        // The automatic merge is queued, not applied, so the save below meets a
        // real conflict and goes through the merge policy.
        #expect(folder.committedValues(forKeys: ["title"])["title"] as? String == "Mine")

        try viewContext.save()

        let checkContext = makePeerContext(for: controller)
        let persisted = try #require(checkContext.object(with: folder.objectID) as? Folder)
        #expect(persisted.title == "Remote")
        #expect(persisted.createdAt == fixedDate)
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
