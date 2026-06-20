import CloudKit
import Foundation

// Family-sharing domain types and the sharing port. CloudKit's `CKShare` is the
// access-control mechanism (ADR-0006): a shared wishlist is a `CKShare` over the
// list's record hierarchy, and the share owner is the family admin.

/// A member of a shared wishlist, derived from a `CKShare.Participant`.
struct FamilyMember: Identifiable, Sendable, Equatable {
    let id: String
    var name: String?
    var role: FamilyRole
    var permission: SharePermission
}

/// The share owner is the family **admin**, because the data lives in their
/// iCloud (ADR-0006); everyone else is a member.
enum FamilyRole: Sendable, Equatable {
    case admin
    case member

    nonisolated init(_ role: CKShare.ParticipantRole) {
        self = (role == .owner) ? .admin : .member
    }
}

enum SharePermission: Sendable, Equatable {
    case readOnly
    case readWrite
    case unknown

    nonisolated init(_ permission: CKShare.ParticipantPermission) {
        switch permission {
        case .readOnly: self = .readOnly
        case .readWrite: self = .readWrite
        default: self = .unknown
        }
    }
}

extension FamilyMember {
    init(_ participant: CKShare.Participant) {
        let identity = participant.userIdentity
        self.id = identity.userRecordID?.recordName ?? UUID().uuidString
        self.name = identity.nameComponents.map { PersonNameComponentsFormatter().string(from: $0) }
        self.role = FamilyRole(participant.role)
        self.permission = SharePermission(participant.permission)
    }
}

/// The family-sharing port. The network operations require a provisioned
/// CloudKit container and a signed-in iCloud account, so they are verified on
/// device, not in headless tests (ADR-0013); the role/permission mapping above
/// is pure and unit-tested.
@MainActor
protocol AppNameFamilySharing {
    /// Create (or return the existing) `CKShare` over a wishlist's hierarchy.
    func shareWishlist(id: UUID) async throws -> CKShare
    /// The existing share for a wishlist, if it is already shared.
    func existingShare(forWishlist id: UUID) throws -> CKShare?
    /// Members on a wishlist's share, the owner surfaced as admin.
    func members(forWishlist id: UUID) throws -> [FamilyMember]
    /// Accept an invitation received out of band (share sheet or universal link).
    func acceptShare(_ metadata: CKShare.Metadata) async throws
}
