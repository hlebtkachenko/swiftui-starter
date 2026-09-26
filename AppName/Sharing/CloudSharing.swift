import CloudKit
import CoreData

/// Temporary family-sharing scaffolding to verify the `CKShare` round-trip on
/// device: accept an incoming share invitation into the local store,
/// and (on iOS) present the system sharing sheet for a wishlist. The polished
/// in-app sharing UI is future work; this is the minimum needed to prove that a
/// wishlist shared from one iCloud account is accepted by another.

@MainActor
private func acceptAppNameShare(_ metadata: CKShare.Metadata) {
    NSLog("AppName: accepting CloudKit share")
    Task {
        do {
            try await CoreDataAppNameStore(PersistenceController.shared).acceptShare(metadata)
            NSLog("AppName: CloudKit share accepted")
        } catch {
            NSLog("AppName: CloudKit share accept failed: \(error)")
        }
    }
}

#if os(iOS)
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

/// Scene-based apps (SwiftUI uses scenes) receive an accepted CloudKit share
/// here, not on the app delegate: a cold launch from tapping the share link
/// delivers it via `scene(_:willConnectTo:)`, a warm accept via
/// `windowScene(_:userDidAcceptCloudKitShareWith:)`. The delegate only reads the
/// share metadata; SwiftUI still owns the window.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            acceptAppNameShare(metadata)
        }
    }

    func windowScene(_ windowScene: UIWindowScene,
                     userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        acceptAppNameShare(metadata)
    }
}

/// Builds and modally presents the system share sheet for a wishlist. Uses the
/// replacement Apple names for the deprecated
/// `UICloudSharingController(preparationHandler:)`: an `NSItemProvider` with a
/// registered CloudKit share preparation handler inside a
/// `UIActivityViewController`. The sheet drives share creation; the handler
/// creates the share through `NSPersistentCloudKitContainer`. It is presented on
/// the topmost view controller, because embedding it in a SwiftUI `.sheet`
/// yields a blank sheet.
@MainActor
func presentWishlistShare(for list: NSManagedObject) {
    guard let identifier = PersistenceController.cloudKitContainerIdentifier else {
        NSLog("AppName: sharing needs CloudKit sync; set cloudKitContainerIdentifier")
        return
    }
    let listID = list.objectID
    let options = CKAllowedSharingOptions(allowedParticipantPermissionOptions: .any,
                                          allowedParticipantAccessOptions: .specifiedRecipientsOnly)
    let provider = NSItemProvider()
    provider.registerCKShare(container: CKContainer(identifier: identifier),
                             allowedSharingOptions: options) {
        try await makeWishlistShare(listID)
    }
    let configuration = UIActivityItemsConfiguration(itemProviders: [provider])
    presentTopmost(UIActivityViewController(activityItemsConfiguration: configuration))
}

@MainActor
private func makeWishlistShare(_ listID: NSManagedObjectID) async throws -> CKShare {
    let container = PersistenceController.shared.container
    let list = container.viewContext.object(with: listID)
    let (_, share, _) = try await container.share([list], to: nil)
    share[CKShare.SystemFieldKey.title] = "Wishlist" as CKRecordValue
    return share
}

@MainActor
private func presentTopmost(_ viewController: UIViewController) {
    guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
          let root = scene.keyWindow?.rootViewController else {
        NSLog("AppName: no window to present the share sheet")
        return
    }
    var top = root
    while let presented = top.presentedViewController { top = presented }
    if let popover = viewController.popoverPresentationController {
        popover.sourceView = top.view
        popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
        popover.permittedArrowDirections = []
    }
    top.present(viewController, animated: true)
}
#elseif os(macOS)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication,
                     userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        acceptAppNameShare(metadata)
    }
}
#endif
