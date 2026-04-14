import Foundation

#if canImport(CloudKit)
import CloudKit
#endif

actor DefaultCloudShareAcceptanceService: CloudShareAcceptanceService {
    private let client: any CloudKitShareClient
    private let allowedHosts: Set<String>

    private var status: CloudShareAcceptanceStatus

    init(
        client: any CloudKitShareClient,
        allowedHosts: Set<String> = []
    ) {
        self.client = client
        self.allowedHosts = Set(allowedHosts.map { $0.lowercased() })
        self.status = CloudShareAcceptanceStatus(
            availability: .notSupported,
            state: .idle,
            lastURL: nil,
            lastErrorCode: nil,
            lastUpdatedAt: nil
        )
    }

    func currentStatus() async -> CloudShareAcceptanceStatus {
        let availability = await client.availability()
        // Preserve last operation state, but refresh availability so Profile UI is not misleading.
        status.availability = availability
        return status
    }

    func acceptShare(from url: URL) async -> CloudShareAcceptanceStatus {
        let availability = await client.availability()
        status.availability = availability

        if let validationErrorCode = validate(url) {
            status = statusForFailure(
                availability: availability,
                url: url,
                errorCode: validationErrorCode
            )
            return status
        }

        guard availability == .available else {
            status = statusForFailure(
                availability: availability,
                url: url,
                errorCode: errorCode(forAvailability: availability)
            )
            return status
        }

        status = CloudShareAcceptanceStatus(
            availability: availability,
            state: .processing,
            lastURL: url,
            lastErrorCode: nil,
            lastUpdatedAt: Date()
        )

        do {
            try await client.acceptShare(from: url)
            status = CloudShareAcceptanceStatus(
                availability: availability,
                state: .accepted,
                lastURL: url,
                lastErrorCode: nil,
                lastUpdatedAt: Date()
            )
        } catch {
            status = statusForFailure(
                availability: availability,
                url: url,
                errorCode: errorCode(for: error)
            )
        }

        return status
    }

    #if canImport(CloudKit)
    func acceptShare(from metadata: CKShare.Metadata) async -> CloudShareAcceptanceStatus {
        let availability = await client.availability()
        status.availability = availability

        guard availability == .available else {
            status = statusForFailure(
                availability: availability,
                url: metadata.share.url,
                errorCode: errorCode(forAvailability: availability)
            )
            return status
        }

        status = CloudShareAcceptanceStatus(
            availability: availability,
            state: .processing,
            lastURL: metadata.share.url,
            lastErrorCode: nil,
            lastUpdatedAt: Date()
        )

        do {
            try await client.acceptShare(from: metadata)
            status = CloudShareAcceptanceStatus(
                availability: availability,
                state: .accepted,
                lastURL: metadata.share.url,
                lastErrorCode: nil,
                lastUpdatedAt: Date()
            )
        } catch {
            status = statusForFailure(
                availability: availability,
                url: metadata.share.url,
                errorCode: errorCode(for: error)
            )
        }

        return status
    }
    #endif
}

private extension DefaultCloudShareAcceptanceService {
    func validate(_ url: URL) -> String? {
        guard url.scheme == "https" else { return "invalid_scheme" }
        guard let host = url.host?.lowercased(), !host.isEmpty else { return "missing_host" }
        if !allowedHosts.isEmpty && !allowedHosts.contains(host) {
            return "unsupported_host"
        }
        let shareRoot = "/share"
        guard url.path == shareRoot || url.path.hasPrefix("\(shareRoot)/") else { return "unsupported_path" }
        let tokenPart = url.path.hasPrefix("\(shareRoot)/")
            ? url.path.dropFirst("\(shareRoot)/".count)
            : Substring("")
        let token = tokenPart.split(separator: "/").first ?? ""
        guard !token.isEmpty else { return "missing_token" }
        return nil
    }

    func statusForFailure(
        availability: ServiceAvailability,
        url: URL?,
        errorCode: String
    ) -> CloudShareAcceptanceStatus {
        CloudShareAcceptanceStatus(
            availability: availability,
            state: .failed,
            lastURL: url,
            lastErrorCode: errorCode,
            lastUpdatedAt: Date()
        )
    }

    func errorCode(forAvailability availability: ServiceAvailability) -> String {
        switch availability {
        case .available:
            return "available_unexpected"
        case .notAuthorized:
            return "not_authorized"
        case .notSupported:
            return "not_supported"
        case .failed:
            return "availability_failed"
        }
    }

    func errorCode(for error: Error) -> String {
        if let shareError = error as? CloudShareAcceptanceError {
            return shareError.code
        }

        let nsError = error as NSError
        if !nsError.domain.isEmpty {
            return "\(nsError.domain)#\(nsError.code)"
        }

        return "unknown_error"
    }
}
