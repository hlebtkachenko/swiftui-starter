import SwiftUI

/// The app's menu and keyboard-shortcut layer, shared by every platform's scene.
/// Lives in the spine, not in a view, so the Mac menu bar and the iPad
/// keyboard-shortcut overlay both get the same commands. It is wired to the
/// `AppEnvironment` passed at construction.
struct AppNameCommands: Commands {
    let environment: AppEnvironment

    var body: some Commands {
        // A "New" entry next to the system New Item slot, with the conventional
        // shortcut. The action goes through the store port, so the command is
        // independent of any particular screen.
        CommandGroup(after: .newItem) {
            Button("New List") {
                _ = try? environment.store.createWishlist(title: "New List")
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        // A manual sync/account re-check, useful when the user has just signed in
        // to iCloud or come back online.
        CommandGroup(after: .toolbar) {
            Button("Refresh iCloud Status") {
                Task { await environment.connectivity.refreshAccount() }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}
