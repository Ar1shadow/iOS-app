import Foundation

protocol CloudKitShareClient {
    func availability() async -> ServiceAvailability
    func acceptShare(from url: URL) async throws
}

struct CloudShareAcceptanceError: Error, Equatable {
    let code: String
}

