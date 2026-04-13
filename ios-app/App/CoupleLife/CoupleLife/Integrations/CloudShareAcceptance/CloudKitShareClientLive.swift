import Foundation

#if canImport(CloudKit)
import CloudKit
#endif

final class CloudKitShareClientLive: CloudKitShareClient {
    #if canImport(CloudKit)
    private let container: CKContainer

    init(container: CKContainer = .default()) {
        self.container = container
    }
    #else
    init() {}
    #endif

    func availability() async -> ServiceAvailability {
        #if canImport(CloudKit)
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                return .available
            case .noAccount, .couldNotDetermine, .temporarilyUnavailable, .restricted:
                return .notAuthorized
            @unknown default:
                return .failed("CloudKit account status is unknown.")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
        #else
        return .notSupported
        #endif
    }

    func acceptShare(from url: URL) async throws {
        #if canImport(CloudKit)
        guard url.scheme == "https", let host = url.host, !host.isEmpty else {
            throw CloudShareAcceptanceError(code: "invalid_url")
        }

        do {
            let metadata = try await fetchShareMetadata(from: url)
            try await acceptShare(with: metadata)
        } catch {
            throw CloudShareAcceptanceError(code: errorCode(for: error))
        }
        #else
        throw CloudShareAcceptanceError(code: "not_supported")
        #endif
    }
}

#if canImport(CloudKit)
private extension CloudKitShareClientLive {
    func fetchShareMetadata(from url: URL) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchShareMetadataOperation(shareURLs: [url])
            var fetchedMetadata: CKShare.Metadata?
            var perShareError: Error?

            operation.perShareMetadataBlock = { _, metadata, error in
                if let error {
                    perShareError = error
                    return
                }
                if let metadata {
                    fetchedMetadata = metadata
                }
            }

            operation.fetchShareMetadataCompletionBlock = { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let perShareError {
                    continuation.resume(throwing: perShareError)
                    return
                }
                guard let fetchedMetadata else {
                    continuation.resume(throwing: CloudShareAcceptanceError(code: "missing_share_metadata"))
                    return
                }
                continuation.resume(returning: fetchedMetadata)
            }

            container.add(operation)
        }
    }

    func acceptShare(with metadata: CKShare.Metadata) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            var perShareError: Error?

            operation.perShareCompletionBlock = { _, _, error in
                if let error {
                    perShareError = error
                }
            }

            operation.acceptSharesCompletionBlock = { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let perShareError {
                    continuation.resume(throwing: perShareError)
                    return
                }
                continuation.resume()
            }

            container.add(operation)
        }
    }

    func errorCode(for error: Error) -> String {
        if let shareError = error as? CloudShareAcceptanceError {
            return shareError.code
        }

        if let ckError = error as? CKError {
            return "ck_\(String(describing: ckError.code))"
        }

        let nsError = error as NSError
        if nsError.domain == CKErrorDomain, let code = CKError.Code(rawValue: nsError.code) {
            return "ck_\(String(describing: code))"
        }

        if !nsError.domain.isEmpty {
            return "\(nsError.domain)#\(nsError.code)"
        }

        return "unknown_error"
    }
}
#endif
