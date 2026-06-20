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

    // Fallback for the non-scene delivery path.
    func application(_ application: UIApplication,
                     userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        acceptAppNameShare(metadata)
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

/// Required delegate for `UICloudSharingController`. Retained via the shared
/// instance because the controller holds its delegate weakly.
final class CloudSharingDelegate: NSObject, UICloudSharingControllerDelegate {
    static let shared = CloudSharingDelegate()

    func itemTitle(for csc: UICloudSharingController) -> String? { "Wishlist" }

    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        NSLog("AppName: share save failed: \(error)")
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        NSLog("AppName: share saved")
    }
}

/// Builds and modally presents the system sharing sheet for a wishlist. Uses the
/// `preparationHandler` init so the controller drives share creation and saving
/// (the reliable path for `NSPersistentCloudKitContainer`), and presents it on
/// the topmost view controller — embedding it in a SwiftUI `.sheet` yields a
/// blank sheet.
@MainActor
func presentWishlistShare(for list: NSManagedObject) {
    let container = PersistenceController.shared.container
    let controller = UICloudSharingController { _, completion in
        container.share([list], to: nil) { _, share, ckContainer, error in
            share?[CKShare.SystemFieldKey.title] = "Wishlist" as CKRecordValue
            completion(share, ckContainer, error)
        }
    }
    controller.delegate = CloudSharingDelegate.shared
    controller.availablePermissions = [.allowPrivate, .allowReadWrite, .allowReadOnly]
    presentTopmost(controller)
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
