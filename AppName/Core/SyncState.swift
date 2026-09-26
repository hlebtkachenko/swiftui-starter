import CloudKit
import CoreData
import Foundation

/// What the data spine is doing, surfaced to the UI. Domain-agnostic: it knows
/// nothing about the app's data, only about sync, account, and network health.
enum SyncState: Equatable, Sendable {
    case idle
    case syncing
    case offline
    case accountUnavailable(reason: String)
    case error(message: String)

    /// A short, user-facing label.
    var label: String {
        switch self {
        case .idle: "Up to date"
        case .syncing: "Syncing…"
        case .offline: "Offline"
        case .accountUnavailable(let reason): reason
        case .error(let message): message
        }
    }

    /// The single status to show in chrome. A store-load failure wins, then an
    /// unusable iCloud account, then being offline, then sync progress. An account
    /// still being checked (`.unknown`) shows nothing rather than a false alarm.
    static func display(account: AccountState, isOnline: Bool, sync: SyncState, storeError: String?) -> SyncState {
        if let storeError { return .error(message: storeError) }
        if account != .available, account != .unknown { return .accountUnavailable(reason: account.label) }
        if !isOnline { return .offline }
        return sync
    }
}

/// The iCloud account condition, mapped off CloudKit's `CKAccountStatus` so the
/// rest of the app never imports CloudKit just to read it.
enum AccountState: Equatable, Sendable {
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case couldNotDetermine
    case unknown

    init(_ status: CKAccountStatus) {
        switch status {
        case .available: self = .available
        case .noAccount: self = .noAccount
        case .restricted: self = .restricted
        case .temporarilyUnavailable: self = .temporarilyUnavailable
        case .couldNotDetermine: self = .couldNotDetermine
        @unknown default: self = .unknown
        }
    }

    var label: String {
        switch self {
        case .available: "Signed in"
        case .noAccount: "Sign in to iCloud to sync"
        case .restricted: "iCloud is restricted on this device"
        case .temporarilyUnavailable: "iCloud is temporarily unavailable"
        case .couldNotDetermine: "Couldn't check the iCloud account"
        case .unknown: "Checking iCloud account…"
        }
    }
}

/// A CloudKit mirroring event, reduced to a `Sendable`, `Equatable` value so the
/// sync logic that consumes it is testable without a live CloudKit container.
struct CloudSyncEvent: Sendable, Equatable {
    enum Kind: Sendable, Equatable { case setup, importData, export, unknown }

    var id: UUID
    var kind: Kind
    /// `true` while the phase is running (no end date yet).
    var inProgress: Bool
    var errorDescription: String?

    init(id: UUID = UUID(), kind: Kind, inProgress: Bool, errorDescription: String? = nil) {
        self.id = id
        self.kind = kind
        self.inProgress = inProgress
        self.errorDescription = errorDescription
    }

    init(_ event: NSPersistentCloudKitContainer.Event) {
        self.id = event.identifier
        switch event.type {
        case .setup: self.kind = .setup
        case .import: self.kind = .importData
        case .export: self.kind = .export
        @unknown default: self.kind = .unknown
        }
        self.inProgress = event.endDate == nil
        self.errorDescription = event.error.map(SyncErrorMapper.describe)
    }
}

/// A human-facing read of a sync error. Pure and testable; CloudKit is inspected
/// via the bridged `NSError` so no `CKError` value has to be constructed by callers.
enum SyncErrorMapper {
    static func describe(_ error: Error) -> String {
        let ns = error as NSError
        if ns.domain == CKErrorDomain {
            switch ns.code {
            case CKError.Code.networkUnavailable.rawValue,
                 CKError.Code.networkFailure.rawValue,
                 CKError.Code.serviceUnavailable.rawValue,
                 CKError.Code.requestRateLimited.rawValue,
                 CKError.Code.zoneBusy.rawValue:
                return "A network problem interrupted sync. It will retry automatically."
            case CKError.Code.quotaExceeded.rawValue:
                return "Your iCloud storage is full. Free up space to keep syncing."
            case CKError.Code.notAuthenticated.rawValue:
                return "Sign in to iCloud to sync."
            default:
                return "Sync hit a problem and will retry."
            }
        }
        let fallback = ns.localizedDescription.isEmpty ? "Sync hit a problem and will retry." : ns.localizedDescription
        return fallback
    }
}
