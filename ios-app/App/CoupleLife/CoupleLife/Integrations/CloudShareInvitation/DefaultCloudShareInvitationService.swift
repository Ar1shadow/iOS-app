import Foundation

#if canImport(CloudKit)
import CloudKit
#endif

actor DefaultCloudShareInvitationService: CloudShareInvitationService {
    private let client: any CloudKitShareInvitationClient
    private let cache: InvitationCacheStore

    private var status: CloudShareInvitationStatus

    init(
        client: any CloudKitShareInvitationClient,
        cache: InvitationCacheStore = UserDefaultsInvitationCacheStore()
    ) {
        self.client = client
        self.cache = cache
        if let cached = cache.lastKnownShareURL {
            self.status = CloudShareInvitationStatus(
                availability: .notSupported,
                state: .active,
                lastShareURL: cached,
                participantCount: 0,
                lastErrorCode: nil,
                lastUpdatedAt: cache.lastUpdatedAt
            )
        } else {
            self.status = CloudShareInvitationStatus(
                availability: .notSupported,
                state: .idle,
                lastShareURL: nil,
                participantCount: 0,
                lastErrorCode: nil,
                lastUpdatedAt: nil
            )
        }
    }

    func currentStatus() async -> CloudShareInvitationStatus {
        let availability = await client.availability()
        status.availability = availability
        return status
    }

    func createShare() async -> CloudShareInvitationStatus {
        let availability = await client.availability()
        status.availability = availability

        guard availability == .available else {
            status = failure(availability: availability, errorCode: errorCode(forAvailability: availability))
            return status
        }

        status = CloudShareInvitationStatus(
            availability: availability,
            state: .creating,
            lastShareURL: status.lastShareURL,
            participantCount: status.participantCount,
            lastErrorCode: nil,
            lastUpdatedAt: Date()
        )

        do {
            let result = try await client.ensureShareRootAndCreate()
            status = CloudShareInvitationStatus(
                availability: availability,
                state: .active,
                lastShareURL: result.shareURL,
                participantCount: result.participantCount,
                lastErrorCode: nil,
                lastUpdatedAt: Date()
            )
            cache.lastKnownShareURL = result.shareURL
            cache.lastUpdatedAt = status.lastUpdatedAt
        } catch {
            status = failure(availability: availability, errorCode: errorCode(for: error))
        }

        return status
    }

    func revokeShare() async -> CloudShareInvitationStatus {
        let availability = await client.availability()
        status.availability = availability

        guard availability == .available else {
            status = failure(availability: availability, errorCode: errorCode(forAvailability: availability))
            return status
        }

        status = CloudShareInvitationStatus(
            availability: availability,
            state: .revoking,
            lastShareURL: status.lastShareURL,
            participantCount: status.participantCount,
            lastErrorCode: nil,
            lastUpdatedAt: Date()
        )

        do {
            try await client.revokeShare()
            status = CloudShareInvitationStatus(
                availability: availability,
                state: .revoked,
                lastShareURL: nil,
                participantCount: 0,
                lastErrorCode: nil,
                lastUpdatedAt: Date()
            )
            cache.lastKnownShareURL = nil
            cache.lastUpdatedAt = status.lastUpdatedAt
        } catch {
            status = failure(availability: availability, errorCode: errorCode(for: error))
        }

        return status
    }

    func reinvite() async -> CloudShareInvitationStatus {
        let revoked = await revokeShare()
        guard revoked.state == .revoked else {
            return revoked
        }
        return await createShare()
    }
}

private extension DefaultCloudShareInvitationService {
    func failure(availability: ServiceAvailability, errorCode: String) -> CloudShareInvitationStatus {
        CloudShareInvitationStatus(
            availability: availability,
            state: .failed,
            lastShareURL: status.lastShareURL,
            participantCount: status.participantCount,
            lastErrorCode: errorCode,
            lastUpdatedAt: Date()
        )
    }

    func errorCode(forAvailability availability: ServiceAvailability) -> String {
        switch availability {
        case .available: return "available_unexpected"
        case .notAuthorized: return "not_authorized"
        case .notSupported: return "not_supported"
        case .failed: return "availability_failed"
        }
    }

    func errorCode(for error: Error) -> String {
        if let invitationError = error as? CloudShareInvitationError {
            return invitationError.code
        }
        let nsError = error as NSError
        if !nsError.domain.isEmpty {
            return "\(nsError.domain)#\(nsError.code)"
        }
        return "unknown_error"
    }
}

protocol InvitationCacheStore: AnyObject {
    var lastKnownShareURL: URL? { get set }
    var lastUpdatedAt: Date? { get set }
}

final class UserDefaultsInvitationCacheStore: InvitationCacheStore {
    private let defaults: UserDefaults
    private let urlKey = "CloudShareInvitation.lastShareURL"
    private let updatedAtKey = "CloudShareInvitation.lastUpdatedAt"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastKnownShareURL: URL? {
        get {
            guard let raw = defaults.string(forKey: urlKey) else { return nil }
            return URL(string: raw)
        }
        set {
            if let url = newValue {
                defaults.set(url.absoluteString, forKey: urlKey)
            } else {
                defaults.removeObject(forKey: urlKey)
            }
        }
    }

    var lastUpdatedAt: Date? {
        get { defaults.object(forKey: updatedAtKey) as? Date }
        set {
            if let date = newValue {
                defaults.set(date, forKey: updatedAtKey)
            } else {
                defaults.removeObject(forKey: updatedAtKey)
            }
        }
    }
}

final class InMemoryInvitationCacheStore: InvitationCacheStore {
    var lastKnownShareURL: URL?
    var lastUpdatedAt: Date?

    init(lastKnownShareURL: URL? = nil, lastUpdatedAt: Date? = nil) {
        self.lastKnownShareURL = lastKnownShareURL
        self.lastUpdatedAt = lastUpdatedAt
    }
}
