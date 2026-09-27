import CoreData

/// Programmatic Core Data model. Built in code (no `.xcdatamodeld` bundle) so it
/// is fully reviewable as version-controlled Swift and plays well with the
/// project's filesystem-synchronized groups (ADR-0015).
///
/// A generic example: folders that hold items. Replace it with your app's
/// domain. Identity is the `NSManagedObjectID`; there is no `id` attribute.
///
/// CloudKit compatibility (ADR-0005): every attribute is optional or has a
/// default, every relationship is optional with an explicit inverse, and no
/// relationship uses the Deny delete rule.
nonisolated enum AppNameModel {
    enum Entity {
        static let folder = "Folder"
        static let item = "Item"
    }

    static func make() -> NSManagedObjectModel {
        let folder = entity(named: Entity.folder, class: Folder.self)
        let item = entity(named: Entity.item, class: Item.self)

        folder.properties = [
            attribute("title", .stringAttributeType, defaultValue: ""),
            attribute("createdAt", .dateAttributeType),
        ]
        item.properties = [
            attribute("title", .stringAttributeType, defaultValue: ""),
            attribute("createdAt", .dateAttributeType),
        ]

        // Folder <->> Item: optional both ends, explicit inverse, cascade from the
        // folder (no Deny rule, per CloudKit).
        let items = NSRelationshipDescription()
        items.name = "items"
        items.destinationEntity = item
        items.minCount = 0
        items.maxCount = 0  // 0 means to-many
        items.isOptional = true
        items.deleteRule = .cascadeDeleteRule

        let owner = NSRelationshipDescription()
        owner.name = "folder"
        owner.destinationEntity = folder
        owner.minCount = 0
        owner.maxCount = 1  // to-one
        owner.isOptional = true
        owner.deleteRule = .nullifyDeleteRule

        items.inverseRelationship = owner
        owner.inverseRelationship = items
        folder.properties.append(items)
        item.properties.append(owner)

        let model = NSManagedObjectModel()
        model.entities = [folder, item]
        return model
    }

    private static func entity(named name: String, class cls: AnyClass) -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = name
        e.managedObjectClassName = NSStringFromClass(cls)
        return e
    }

    private static func attribute(_ name: String, _ type: NSAttributeType, defaultValue: Any? = nil) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name
        a.attributeType = type
        a.isOptional = true  // optional at the model level for CloudKit; required in code
        if let defaultValue { a.defaultValue = defaultValue }
        return a
    }
}
