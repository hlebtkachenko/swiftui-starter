import CoreData

#if DEBUG
/// Debug-only demo content for screenshots and manual testing, seeded by the
/// `-demoContent` launch argument. Compiled out of Release builds.
extension AppNameStore {
    static let demoContent: [(folder: String, items: [String])] = [
        ("Groceries", ["Oat milk", "Sourdough loaf", "Lemons", "Coffee beans"]),
        ("Trip to Lisbon", ["Book the flight", "Pack a rain jacket", "Tram 28 tickets"]),
        ("Reading List", ["The Pragmatic Programmer", "Thinking in Systems", "A Philosophy of Software Design"]),
        ("Home Projects", ["Fix the hallway light", "Repaint the balcony door", "Hang the shelves", "Seal the bathtub"]),
    ]

    /// Insert the demo folders and items, only when the store has no folders, so
    /// a second launch with the flag changes nothing. Returns whether it seeded.
    @discardableResult
    func seedDemoContentIfEmpty() throws -> Bool {
        guard try folderCount() == 0 else { return false }
        for entry in Self.demoContent {
            let folder = try createFolder(title: entry.folder)
            for title in entry.items {
                try createItem(in: folder, title: title)
            }
        }
        return true
    }
}
#endif
