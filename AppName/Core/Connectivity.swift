import CloudKit
import Foundation
import Network
import Observation
import OSLog

/// Network reachability and iCloud account status. Domain-agnostic: it reports
/// whether the device is online and whether an iCloud account is usable, so the
/// UI can explain why sync is or is not happening.
@Observable
final class Connectivity {
    private(set) var isOnline = true
    private(set) var account: AccountState = .unknown

    private let containerIdentifier: String?

    /// `nil` runs as a pure local store (no CloudKit), which reports `.available`
    /// so the local app is never blocked on an account check.
    init(containerIdentifier: String?) {
        self.containerIdentifier = containerIdentifier
    }

    func start() {
        // Without CloudKit nothing syncs, so being offline is not worth a chip.
        if containerIdentifier != nil {
            Task { [weak self] in
                for await path in NWPathMonitor() {
                    self?.isOnline = path.status == .satisfied
                }
            }
        }
        // Subscribe before the first check so a change during it is not missed.
        let accountChanges = NotificationCenter.default.notifications(named: .CKAccountChanged)
        Task { [weak self] in
            await self?.refreshAccount()
            for await _ in accountChanges {
                await self?.refreshAccount()
            }
        }
    }

    func refreshAccount() async {
        guard let containerIdentifier else {
            account = .available
            return
        }
        do {
            let status = try await CKContainer(identifier: containerIdentifier).accountStatus()
            account = AccountState(status)
        } catch {
            Log.connectivity.error("account status check failed: \(error.localizedDescription, privacy: .public)")
            account = .couldNotDetermine
        }
    }
}
