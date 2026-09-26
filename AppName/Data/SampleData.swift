import CoreData

/// Deterministic seed data for previews and tests. Lives in the data layer and
/// carries no view dependencies (patterns.md). Uses the public `AppNameStore` API so
/// the seed exercises the same code paths as the app.
enum SampleData {
    @MainActor
    static func populate(_ context: NSManagedObjectContext) throws {
        let store = CoreDataAppNameStore(context: context)
        let birthday = try store.createWishlist(title: "Mom's Birthday")
        try store.addItem(to: birthday.id, title: "Gardening gloves", note: "Size M", url: nil)
        try store.addItem(to: birthday.id, title: "Cookbook", note: nil,
                          url: URL(string: "https://example.com/cookbook"))
    }
}
