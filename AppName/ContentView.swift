import SwiftUI
import CoreData
import OSLog

struct ContentView: View {
    @Environment(AppEnvironment.self) private var environment
    @FetchRequest(fetchRequest: Folder.sortedFetchRequest()) private var folders: FetchedResults<Folder>
    @State private var selection: NSManagedObjectID?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(folders, id: \.objectID) { folder in
                    Text(folder.title ?? "")
                        .tag(folder.objectID)
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) { delete(folder) }
                                .disabled(!environment.store.canEdit(folder))
                        }
                        .deleteDisabled(!environment.store.canEdit(folder))
                }
                .onDelete { offsets in
                    offsets.map { folders[$0] }.forEach(delete)
                }
            }
            .overlay {
                if folders.isEmpty {
                    ContentUnavailableView("No Folders", systemImage: "folder")
                }
            }
            .navigationTitle("Folders")
            .toolbar {
                ToolbarItem {
                    Button("New Folder", systemImage: "folder.badge.plus") {
                        environment.write("create a folder") { try $0.createFolder(title: String(localized: "New Folder")) }
                    }
                }
                ToolbarItem(placement: .status) {
                    SyncStatusChip(state: environment.displayState, onDismiss: environment.sync.dismissReportedError)
                }
            }
        } detail: {
            // A folder deleted elsewhere (another device, a revoked share) drops out
            // of the fetch, and the placeholder takes its place.
            if let folder = folders.first(where: { $0.objectID == selection }) {
                FolderDetailView(folder: folder)
            } else {
                ContentUnavailableView("No Folder Selected", systemImage: "folder")
            }
        }
    }

    private func delete(_ folder: Folder) {
        environment.write("delete a folder") { try $0.delete(folder) }
    }
}

private struct FolderDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @ObservedObject private var folder: Folder
    @FetchRequest private var items: FetchedResults<Item>

    init(folder: Folder) {
        self.folder = folder
        _items = FetchRequest(fetchRequest: Item.sortedFetchRequest(in: folder))
    }

    /// `false` on a folder shared to this user read-only.
    private var canEdit: Bool { environment.store.canEdit(folder) }

    var body: some View {
        List {
            ForEach(items, id: \.objectID) { item in
                Text(item.title ?? "")
            }
            .onDelete { offsets in
                let doomed = offsets.map { items[$0] }
                environment.write("delete an item") { store in try doomed.forEach(store.delete) }
            }
            .deleteDisabled(!canEdit)
        }
        .overlay {
            if items.isEmpty {
                ContentUnavailableView("No Items", systemImage: "doc")
            }
        }
        .navigationTitle(folder.title ?? "")
        .toolbar {
            ToolbarItem {
                Button("New Item", systemImage: "plus") {
                    environment.write("create an item") {
                        try $0.createItem(in: folder, title: String(localized: "New Item"))
                    }
                }
                .disabled(!canEdit)
            }
            // The system share sheet, shown only while sync is on.
            if let shareItem {
                ToolbarItem {
                    ShareLink(item: shareItem, preview: SharePreview(folder.title ?? "")) {
                        Label("Share", systemImage: "person.crop.circle.badge.plus")
                    }
                }
            }
        }
    }

    private var shareItem: CloudShareItem? {
        do {
            return try environment.store.shareItem(for: folder)
        } catch {
            Log.sharing.error("share lookup failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController(inMemory: true))
    environment.write("create preview content") { store in
        let folder = try store.createFolder(title: String(localized: "New Folder"))
        try store.createItem(in: folder, title: String(localized: "New Item"))
    }
    return ContentView()
        .environment(\.managedObjectContext, environment.viewContext)
        .environment(environment)
}
