import CoreData

// `NSManagedObject` subclasses for the programmatic model. Views read them with
// `@FetchRequest` (ADR-0003) through the shared sorted requests below. They are
// nonisolated: Core Data uses them on whatever queue owns their context.

nonisolated final class Folder: NSManagedObject {
    @NSManaged var title: String?
    @NSManaged var createdAt: Date?
    @NSManaged var items: NSSet?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        createdAt = .now
    }

    /// Every folder, oldest first.
    static func sortedFetchRequest() -> NSFetchRequest<Folder> {
        let request = NSFetchRequest<Folder>(entityName: AppNameModel.Entity.folder)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return request
    }
}

nonisolated final class Item: NSManagedObject {
    @NSManaged var title: String?
    @NSManaged var createdAt: Date?
    @NSManaged var folder: Folder?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        createdAt = .now
    }

    /// A folder's items, oldest first.
    static func sortedFetchRequest(in folder: Folder) -> NSFetchRequest<Item> {
        let request = NSFetchRequest<Item>(entityName: AppNameModel.Entity.item)
        request.predicate = NSPredicate(format: "folder == %@", folder)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return request
    }
}
