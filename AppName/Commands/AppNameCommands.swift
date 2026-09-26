import SwiftUI

/// The app's menu and keyboard-shortcut layer, shared by every platform's scene.
/// Lives in the spine, not in a view, so the Mac menu bar and the iPad
/// keyboard-shortcut overlay both get the same commands. It is wired to the
/// `AppEnvironment` passed at construction.
struct AppNameCommands: Commands {
    let environment: AppEnvironment

    var body: some Commands {
        // A "New" entry next to the system New Item slot. Shift-Command-N, because
        // Command-N is the system's New Window. The action goes through the
        // environment's store, so the command is independent of any screen.
        CommandGroup(after: .newItem) {
            Button("New Folder") {
                environment.write("create a folder") { try $0.createFolder(title: String(localized: "New Folder")) }
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
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
