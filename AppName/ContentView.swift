import SwiftUI
import CoreData
import OSLog

struct ContentView: View {
    @Environment(AppEnvironment.self) private var environment
    @FetchRequest(fetchRequest: WishlistMO.fetchAllRequest()) private var wishlists: FetchedResults<WishlistMO>
    @State private var selection: NSManagedObjectID?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(wishlists, id: \.objectID) { list in
                    Text(list.title ?? "Untitled")
                        .tag(list.objectID)
                        .deleteDisabled(!environment.store.canDelete(list))
                }
                .onDelete { offsets in
                    let lists = offsets.map { wishlists[$0] }
                    environment.write("delete a list") { try $0.delete(lists) }
                }
            }
            .navigationTitle("Wishlists")
            .toolbar {
                ToolbarItem {
                    Button("Add list", systemImage: "plus") {
                        environment.write("create a list") { try $0.createWishlist(title: "New list") }
                    }
                }
                ToolbarItem(placement: .status) {
                    SyncStatusChip(state: environment.displayState)
                }
            }
        } detail: {
            if let list = wishlists.first(where: { $0.objectID == selection }) {
                WishlistDetailView(list: list)
            } else {
                ContentUnavailableView("Select a list", systemImage: "gift")
            }
        }
    }
}

private struct WishlistDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @ObservedObject private var list: WishlistMO
    @FetchRequest private var items: FetchedResults<WishItemMO>

    init(list: WishlistMO) {
        self.list = list
        let request = NSFetchRequest<WishItemMO>(entityName: AppNameModel.Entity.wishItem)
        request.predicate = NSPredicate(format: "wishlist == %@", list)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        _items = FetchRequest(fetchRequest: request)
    }

    /// `false` on a list shared to this user read-only.
    private var canEdit: Bool { environment.store.canUpdate(list) }

    var body: some View {
        List {
            ForEach(items, id: \.objectID) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title ?? "Untitled")
                    if let note = item.note, !note.isEmpty {
                        Text(note).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            .onDelete { offsets in
                let doomed = offsets.map { items[$0] }
                environment.write("delete an item") { try $0.delete(doomed) }
            }
            .deleteDisabled(!canEdit)
        }
        .navigationTitle(list.title ?? "Untitled")
        .toolbar {
            if canEdit, let id = list.id {
                ToolbarItem {
                    Button("Add item", systemImage: "plus") {
                        environment.write("add an item") {
                            try $0.addItem(to: id, title: "New item", note: nil, url: nil)
                        }
                    }
                }
            }
            // Temporary: the system share sheet, so a second iCloud account can be
            // invited. Hidden while sync is off.
            if let shareItem {
                ToolbarItem {
                    ShareLink(item: shareItem, preview: SharePreview(list.title ?? "Untitled")) {
                        Label("Share", systemImage: "person.crop.circle.badge.plus")
                    }
                }
            }
        }
    }

    private var shareItem: CloudShareItem? {
        guard let id = list.id else { return nil }
        do {
            return try environment.store.shareItem(forWishlist: id)
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
