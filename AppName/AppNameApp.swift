import SwiftUI
import CoreData

@main
struct AppNameApp: App {
    @State private var environment = AppEnvironment(persistence: .shared)
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, environment.viewContext)
                .environment(environment)
                .task { environment.start() }
        }
        .commands { AppNameCommands(environment: environment) }

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(environment)
        }
        #endif
    }
}
