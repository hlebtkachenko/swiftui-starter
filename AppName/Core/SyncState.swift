import CloudKit
import CoreData
import Foundation

/// What the data spine is doing, surfaced to the UI. Domain-agnostic: it knows
/// nothing about wishlists, only about sync, account, and network health.
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
        case .couldNotDetermine: "Checking iCloud account…"
        case .unknown: "iCloud account status unknown"
        }
    }
}

/// A CloudKit mirroring event, reduced to a `Sendable`, `Equatable` value so the
/// sync logic that consumes it is testable without a live CloudKit container.
struct CloudSyncEvent: Sendable, Equatable {
    enum Kind: Sendable, Equatable { case setup, importData, export, unknown }

    var kind: Kind
    /// `true` while the phase is running (no end date yet).
    var inProgress: Bool
    var errorDescription: String?

    init(kind: Kind, inProgress: Bool, errorDescription: String? = nil) {
        self.kind = kind
        self.inProgress = inProgress
        self.errorDescription = errorDescription
    }

    init(_ event: NSPersistentCloudKitContainer.Event) {
        switch event.type {
        case .setup: self.kind = .setup
        case .import: self.kind = .importData
        case .export: self.kind = .export
        @unknown default: self.kind = .unknown
        }
        self.inProgress = event.endDate == nil
        self.errorDescription = event.error?.localizedDescription
    }
}

/// A human-facing read of a sync error plus whether the system retries it on its
/// own. Pure and testable; CloudKit is inspected via the bridged `NSError` so no
/// `CKError` value has to be constructed by callers.
struct SyncErrorInfo: Equatable, Sendable {
    var message: String
    var isRetryable: Bool
}

enum SyncErrorMapper {
    static func describe(_ error: Error) -> SyncErrorInfo {
        let ns = error as NSError
        if ns.domain == CKErrorDomain {
            switch ns.code {
            case CKError.Code.networkUnavailable.rawValue,
                 CKError.Code.networkFailure.rawValue,
                 CKError.Code.serviceUnavailable.rawValue,
                 CKError.Code.requestRateLimited.rawValue,
                 CKError.Code.zoneBusy.rawValue:
                return SyncErrorInfo(message: "A network problem interrupted sync. It will retry automatically.", isRetryable: true)
            case CKError.Code.quotaExceeded.rawValue:
                return SyncErrorInfo(message: "Your iCloud storage is full. Free up space to keep syncing.", isRetryable: false)
            case CKError.Code.notAuthenticated.rawValue:
                return SyncErrorInfo(message: "Sign in to iCloud to sync.", isRetryable: false)
            default:
                return SyncErrorInfo(message: "Sync hit a problem and will retry.", isRetryable: true)
            }
        }
        let fallback = ns.localizedDescription.isEmpty ? "Sync hit a problem and will retry." : ns.localizedDescription
        return SyncErrorInfo(message: fallback, isRetryable: true)
    }
}
