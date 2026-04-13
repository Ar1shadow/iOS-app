import Foundation

actor DefaultCloudShareAcceptanceService: CloudShareAcceptanceService {
    private let client: any CloudKitShareClient
    private let allowedHosts: Set<String>

    private var status: CloudShareAcceptanceStatus

    init(
        client: any CloudKitShareClient,
        allowedHosts: Set<String> = []
    ) {
        self.client = client
        self.allowedHosts = allowedHosts
        self.status = CloudShareAcceptanceStatus(
            availability: .available,
            state: .idle,
            lastURL: nil,
            lastErrorCode: nil,
            lastUpdatedAt: nil
        )
    }

    func currentStatus() async -> CloudShareAcceptanceStatus {
        status
    }

    func acceptShare(from url: URL) async -> CloudShareAcceptanceStatus {
        if let validationErrorCode = validate(url) {
            status = statusForFailure(
                availability: status.availability,
                url: url,
                errorCode: validationErrorCode
            )
            return status
        }

        let availability = await client.availability()
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
}

private extension DefaultCloudShareAcceptanceService {
    func validate(_ url: URL) -> String? {
        guard url.scheme == "https" else { return "invalid_scheme" }
        guard let host = url.host, !host.isEmpty else { return "missing_host" }
        if !allowedHosts.isEmpty && !allowedHosts.contains(host) {
            return "unsupported_host"
        }
        return nil
    }

    func statusForFailure(
        availability: ServiceAvailability,
        url: URL,
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
