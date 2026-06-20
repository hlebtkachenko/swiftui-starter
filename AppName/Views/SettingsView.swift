#if os(macOS)
import SwiftUI

/// The macOS Settings window. A real multiplatform app exposes a Settings scene
/// on the Mac; for now it surfaces the live spine status (account, network,
/// sync) so the connectivity layer is visible and verifiable. Feature settings
/// fill in later.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        TabView {
            Form {
                LabeledContent("iCloud account", value: environment.connectivity.account.label)
                LabeledContent("Network", value: environment.connectivity.isOnline ? "Online" : "Offline")
                LabeledContent("Sync", value: environment.sync.state.label)
                LabeledContent("Last sync", value: lastSyncText)
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 420, height: 220)
    }

    private var lastSyncText: String {
        guard let date = environment.sync.lastSync else { return "Never" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
#endif
