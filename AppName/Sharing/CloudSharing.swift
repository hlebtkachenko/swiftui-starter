import CloudKit
import CoreTransferable

/// Temporary sharing scaffolding to verify the `CKShare` round-trip on device:
/// hand a record to the system share sheet (`ShareLink`) and accept an incoming
/// invitation into the local store. The polished, role-aware sharing UI is future
/// work.

/// What `ShareLink` shares: the record's existing `CKShare`, or a handler that
/// creates one when the user picks a recipient. One path on iOS and macOS.
nonisolated struct CloudShareItem: Transferable {
    let container: CKContainer
    let existing: CKShare?
    let prepare: @Sendable () async throws -> CKShare

    static var transferRepresentation: some TransferRepresentation {
        CKShareTransferRepresentation { item in
            // Invited people only (no public link), each read-only or read-write.
            let options = CKAllowedSharingOptions(allowedParticipantPermissionOptions: .any,
                                                  allowedParticipantAccessOptions: .specifiedRecipientsOnly)
            if let share = item.existing {
                return .existing(share, container: item.container, allowedSharingOptions: options)
            }
            return .prepareShare(container: item.container, allowedSharingOptions: options,
                                 preparationHandler: item.prepare)
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
            AppEnvironment.shared.acceptShare(metadata)
        }
    }

    func windowScene(_ windowScene: UIWindowScene,
                     userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        AppEnvironment.shared.acceptShare(metadata)
    }
}
#elseif os(macOS)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication,
                     userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        AppEnvironment.shared.acceptShare(metadata)
    }
}
#endif
