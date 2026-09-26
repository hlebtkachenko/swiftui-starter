import SwiftUI
import CoreData
import OSLog

struct ContentView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(AppEnvironment.self) private var environment
    @FetchRequest(fetchRequest: WishlistMO.fetchAllRequest()) private var wishlists: FetchedResults<WishlistMO>
    @State private var selection: UUID?

    private var store: CoreDataAppNameStore { CoreDataAppNameStore(context: context) }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(wishlists, id: \.listID) { list in
                    Text(list.title ?? "Untitled").tag(list.listID)
                }
                .onDelete(perform: deleteWishlists)
            }
            .navigationTitle("Wishlists")
            .toolbar {
                ToolbarItem {
                    Button("Add list", systemImage: "plus") {
                        _ = try? store.createWishlist(title: "New list")
                    }
                }
                ToolbarItem(placement: .status) {
                    SyncStatusChip(state: environment.displayState)
                }
            }
        } detail: {
            if let selection, let list = wishlists.first(where: { $0.listID == selection }) {
                WishlistDetailView(wishlistID: selection, title: list.title ?? "Untitled")
            } else {
                ContentUnavailableView("Select a list", systemImage: "gift")
            }
        }
    }

    private func deleteWishlists(_ offsets: IndexSet) {
        for index in offsets {
            try? store.deleteWishlist(id: wishlists[index].listID)
        }
    }
}

private struct WishlistDetailView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(AppEnvironment.self) private var environment
    private let wishlistID: UUID
    private let title: String
    @FetchRequest private var items: FetchedResults<WishItemMO>

    init(wishlistID: UUID, title: String) {
        self.wishlistID = wishlistID
        self.title = title
        let request = NSFetchRequest<WishItemMO>(entityName: AppNameModel.Entity.wishItem)
        request.predicate = NSPredicate(format: "wishlist.id == %@", wishlistID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        _items = FetchRequest(fetchRequest: request)
    }

    private var store: CoreDataAppNameStore { CoreDataAppNameStore(context: context) }

    var body: some View {
        List {
            ForEach(items, id: \.itemID) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title ?? "Untitled")
                    if let note = item.note, !note.isEmpty {
                        Text(note).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem {
                Button("Add item", systemImage: "plus") {
                    _ = try? store.addItem(to: wishlistID, title: "New item", note: nil, url: nil)
                }
            }
            // Temporary: the system share sheet, so a second iCloud account can be
            // invited. Hidden while sync is off.
            if let shareItem {
                ToolbarItem {
                    ShareLink(item: shareItem, preview: SharePreview(title)) {
                        Label("Share", systemImage: "person.crop.circle.badge.plus")
                    }
                }
            }
        }
    }

    private var shareItem: CloudShareItem? {
        do {
            return try environment.store.shareItem(forWishlist: wishlistID)
        } catch {
            Log.sharing.error("share lookup failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

#Preview {
    let persistence = PersistenceController.preview()
    return ContentView()
        .environment(\.managedObjectContext, persistence.container.viewContext)
        .environment(AppEnvironment(persistence: persistence))
}
