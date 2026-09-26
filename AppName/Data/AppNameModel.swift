import CoreData

/// Programmatic Core Data model. Built in code (no `.xcdatamodeld` bundle) so it
/// is fully reviewable as version-controlled Swift and plays well with the
/// project's filesystem-synchronized groups (ADR-0015).
///
/// CloudKit compatibility (ADR-0005): every attribute is optional or has a
/// default, every relationship is optional with an explicit inverse, and no
/// relationship uses the Deny delete rule.
enum AppNameModel {
    enum Entity {
        nonisolated static let wishlist = "Wishlist"
        nonisolated static let wishItem = "WishItem"
    }

    static func make() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let wishlist = entity(named: Entity.wishlist, class: WishlistMO.self)
        let wishItem = entity(named: Entity.wishItem, class: WishItemMO.self)

        wishlist.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("title", .stringAttributeType, defaultValue: ""),
            attribute("createdAt", .dateAttributeType),
        ]
        wishItem.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("title", .stringAttributeType, defaultValue: ""),
            attribute("note", .stringAttributeType),
            attribute("urlString", .stringAttributeType),
            attribute("createdAt", .dateAttributeType),
        ]

        // Wishlist <->> WishItem: optional both ends, explicit inverse, cascade
        // from the list (no Deny rule, per CloudKit).
        let items = NSRelationshipDescription()
        items.name = "items"
        items.destinationEntity = wishItem
        items.minCount = 0
        items.maxCount = 0 // 0 means to-many
        items.isOptional = true
        items.deleteRule = .cascadeDeleteRule

        let listRef = NSRelationshipDescription()
        listRef.name = "wishlist"
        listRef.destinationEntity = wishlist
        listRef.minCount = 0
        listRef.maxCount = 1 // to-one
        listRef.isOptional = true
        listRef.deleteRule = .nullifyDeleteRule

        items.inverseRelationship = listRef
        listRef.inverseRelationship = items
        wishlist.properties.append(items)
        wishItem.properties.append(listRef)

        model.entities = [wishlist, wishItem]
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
        a.isOptional = true // optional at the model level for CloudKit; required in code
        if let defaultValue { a.defaultValue = defaultValue }
        return a
    }
}
