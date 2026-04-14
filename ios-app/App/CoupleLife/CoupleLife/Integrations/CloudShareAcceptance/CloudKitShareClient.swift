import Foundation

#if canImport(CloudKit)
import CloudKit
#endif

protocol CloudKitShareClient {
    func availability() async -> ServiceAvailability
    func acceptShare(from url: URL) async throws

    #if canImport(CloudKit)
    func acceptShare(from metadata: CKShare.Metadata) async throws
    #endif
}

struct CloudShareAcceptanceError: Error, Equatable {
    let code: String
}
