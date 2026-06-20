import CoreData

/// Programmatic Core Data model. Built in code (no `.xcdatamodeld` bundle) so it
/// is fully reviewable as version-controlled Swift and plays well with the
/// project's filesystem-synchronized groups (ADR-0015).
///
/// CloudKit compatibility (ADR-0005): every attribute is optional or has a
/// default, every relationship is optional with an explicit inverse, and no
/// relationship uses the Deny delete rule.
///
/// The gift-claim partition (ADR-0006) is enforced at the model level: a
/// `GiftClaim` references its item by a loose `UUID`, never a relationship, so it
/// never joins the item's shared object graph. The physical separation into a
/// distinct CloudKit zone/share that excludes the wishlist owner is a follow-up
/// (a follow-up); for now every entity lives in one store.
enum AppNameModel {
    enum Entity {
        nonisolated static let wishlist = "Wishlist"
        nonisolated static let wishItem = "WishItem"
        nonisolated static let giftClaim = "GiftClaim"
    }

    static func make() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let wishlist = entity(named: Entity.wishlist, class: WishlistMO.self)
        let wishItem = entity(named: Entity.wishItem, class: WishItemMO.self)
        let giftClaim = entity(named: Entity.giftClaim, class: GiftClaimMO.self)

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
        giftClaim.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("itemID", .UUIDAttributeType),
            attribute("claimedBy", .stringAttributeType, defaultValue: ""),
            attribute("statusRaw", .integer16AttributeType, defaultValue: 0),
            attribute("claimedAt", .dateAttributeType),
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

        // GiftClaim has no relationship to WishItem: it references the item by a
        // loose UUID, which is what keeps it out of the item's shared graph.

        model.entities = [wishlist, wishItem, giftClaim]
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
