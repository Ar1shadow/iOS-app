import Foundation

#if canImport(CloudKit)
import CloudKit
#endif

struct CloudShareInvitationCreateResult {
    let shareURL: URL
    let participantCount: Int
}

protocol CloudKitShareInvitationClient {
    func availability() async -> ServiceAvailability
    func ensureShareRootAndCreate() async throws -> CloudShareInvitationCreateResult
    func fetchExistingShare() async throws -> CloudShareInvitationCreateResult?
    func revokeShare() async throws
}

struct CloudShareInvitationError: Error, Equatable {
    let code: String
}
