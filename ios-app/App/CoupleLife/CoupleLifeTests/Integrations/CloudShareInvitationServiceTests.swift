import XCTest
@testable import CoupleLife

#if canImport(CloudKit)
import CloudKit
#endif

final class CloudShareInvitationServiceTests: XCTestCase {
    private func makeURL(_ string: String = "https://icloud.com/share/abc") -> URL {
        URL(string: string)!
    }

    func testCreateShareFailsWhenAvailabilityNotAuthorized() async {
        let client = FakeShareInvitationClient(availability: .notAuthorized)
        let service = DefaultCloudShareInvitationService(client: client, cache: InMemoryInvitationCacheStore())

        let status = await service.createShare()

        XCTAssertEqual(status.state, CloudShareInvitationState.failed)
        XCTAssertEqual(status.availability, .notAuthorized)
        XCTAssertEqual(status.lastErrorCode, "not_authorized")
    }

    func testCreateShareTransitionsToCreatingWhileInFlight() async {
        let client = BlockingShareInvitationClient(availability: .available, shareURL: makeURL())
        let service = DefaultCloudShareInvitationService(client: client, cache: InMemoryInvitationCacheStore())

        let task = Task { await service.createShare() }

        await client.waitUntilCreateStarts()
        let mid = await service.currentStatus()
        XCTAssertEqual(mid.state, .creating)

        await client.finishCreateSuccessfully()
        let final = await task.value
        XCTAssertEqual(final.state, .active)
        XCTAssertEqual(final.lastShareURL, makeURL())
        XCTAssertNil(final.lastErrorCode)
    }

    func testCreateShareMapsClientFailureToErrorCode() async {
        let client = FailingShareInvitationClient(
            availability: .available,
            error: CloudShareInvitationError(code: "network_unavailable")
        )
        let service = DefaultCloudShareInvitationService(client: client, cache: InMemoryInvitationCacheStore())

        let status = await service.createShare()

        XCTAssertEqual(status.state, CloudShareInvitationState.failed)
        XCTAssertEqual(status.lastErrorCode, "network_unavailable")
    }

    func testRevokeShareTransitionsToRevoked() async {
        let client = BlockingShareInvitationClient(availability: .available, shareURL: makeURL())
        let service = DefaultCloudShareInvitationService(client: client, cache: InMemoryInvitationCacheStore())

        _ = await primeActive(service: service, client: client)

        let task = Task { await service.revokeShare() }
        await client.waitUntilRevokeStarts()
        let mid = await service.currentStatus()
        XCTAssertEqual(mid.state, .revoking)

        await client.finishRevokeSuccessfully()
        let final = await task.value
        XCTAssertEqual(final.state, .revoked)
        XCTAssertNil(final.lastShareURL)
    }

    func testRevokeShareSurfacesShareNotFound() async {
        let client = FailingShareInvitationClient(
            availability: .available,
            error: CloudShareInvitationError(code: "share_not_found")
        )
        let service = DefaultCloudShareInvitationService(client: client, cache: InMemoryInvitationCacheStore())

        let status = await service.revokeShare()
        XCTAssertEqual(status.state, CloudShareInvitationState.failed)
        XCTAssertEqual(status.lastErrorCode, "share_not_found")
    }

    func testReinviteRunsRevokeThenCreate() async {
        let firstURL = makeURL("https://icloud.com/share/first")
        let secondURL = makeURL("https://icloud.com/share/second")
        let client = SequentialShareInvitationClient(
            availability: .available,
            createResults: [firstURL, secondURL]
        )
        let service = DefaultCloudShareInvitationService(client: client, cache: InMemoryInvitationCacheStore())

        let first = await service.createShare()
        XCTAssertEqual(first.state, .active)
        XCTAssertEqual(first.lastShareURL, firstURL)

        let reinvited = await service.reinvite()
        XCTAssertEqual(reinvited.state, .active)
        XCTAssertEqual(reinvited.lastShareURL, secondURL)
    }

    func testReinviteStopsAtRevokeFailure() async {
        let client = RevokeFailingClient(
            availability: .available,
            revokeError: CloudShareInvitationError(code: "ck_serviceUnavailable")
        )
        let service = DefaultCloudShareInvitationService(client: client, cache: InMemoryInvitationCacheStore())

        let status = await service.reinvite()
        XCTAssertEqual(status.state, CloudShareInvitationState.failed)
        XCTAssertEqual(status.lastErrorCode, "ck_serviceUnavailable")
    }

    private func primeActive(
        service: DefaultCloudShareInvitationService,
        client: BlockingShareInvitationClient
    ) async {
        let task = Task { await service.createShare() }
        await client.waitUntilCreateStarts()
        await client.finishCreateSuccessfully()
        _ = await task.value
    }
}

private actor BlockingShareInvitationClient: CloudKitShareInvitationClient {
    private let accountAvailability: ServiceAvailability
    private let shareURL: URL
    private var createStarted = false
    private var createContinuation: CheckedContinuation<Void, Never>?
    private var revokeStarted = false
    private var revokeContinuation: CheckedContinuation<Void, Never>?

    init(availability: ServiceAvailability, shareURL: URL) {
        self.accountAvailability = availability
        self.shareURL = shareURL
    }

    func availability() async -> ServiceAvailability { accountAvailability }

    func ensureShareRootAndCreate() async throws -> CloudShareInvitationCreateResult {
        createStarted = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.createContinuation = continuation
        }
        return CloudShareInvitationCreateResult(shareURL: shareURL, participantCount: 1)
    }

    func fetchExistingShare() async throws -> CloudShareInvitationCreateResult? { nil }

    func revokeShare() async throws {
        revokeStarted = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.revokeContinuation = continuation
        }
    }

    func waitUntilCreateStarts() async {
        while !createStarted { await Task.yield() }
    }

    func finishCreateSuccessfully() async {
        createContinuation?.resume()
        createContinuation = nil
    }

    func waitUntilRevokeStarts() async {
        while !revokeStarted { await Task.yield() }
    }

    func finishRevokeSuccessfully() async {
        revokeContinuation?.resume()
        revokeContinuation = nil
    }
}

private struct FakeShareInvitationClient: CloudKitShareInvitationClient {
    let accountAvailability: ServiceAvailability

    init(availability: ServiceAvailability) { self.accountAvailability = availability }

    func availability() async -> ServiceAvailability { accountAvailability }
    func ensureShareRootAndCreate() async throws -> CloudShareInvitationCreateResult {
        throw CloudShareInvitationError(code: "unexpected")
    }
    func fetchExistingShare() async throws -> CloudShareInvitationCreateResult? { nil }
    func revokeShare() async throws {}
}

private struct FailingShareInvitationClient: CloudKitShareInvitationClient {
    let accountAvailability: ServiceAvailability
    let error: CloudShareInvitationError

    init(availability: ServiceAvailability, error: CloudShareInvitationError) {
        self.accountAvailability = availability
        self.error = error
    }

    func availability() async -> ServiceAvailability { accountAvailability }
    func ensureShareRootAndCreate() async throws -> CloudShareInvitationCreateResult { throw error }
    func fetchExistingShare() async throws -> CloudShareInvitationCreateResult? { nil }
    func revokeShare() async throws { throw error }
}

private actor SequentialShareInvitationClient: CloudKitShareInvitationClient {
    private let accountAvailability: ServiceAvailability
    private var createURLs: [URL]

    init(availability: ServiceAvailability, createResults: [URL]) {
        self.accountAvailability = availability
        self.createURLs = createResults
    }

    func availability() async -> ServiceAvailability { accountAvailability }

    func ensureShareRootAndCreate() async throws -> CloudShareInvitationCreateResult {
        guard !createURLs.isEmpty else {
            throw CloudShareInvitationError(code: "no_more_results")
        }
        let url = createURLs.removeFirst()
        return CloudShareInvitationCreateResult(shareURL: url, participantCount: 1)
    }

    func fetchExistingShare() async throws -> CloudShareInvitationCreateResult? { nil }
    func revokeShare() async throws {}
}

private struct RevokeFailingClient: CloudKitShareInvitationClient {
    let accountAvailability: ServiceAvailability
    let revokeError: CloudShareInvitationError

    init(availability: ServiceAvailability, revokeError: CloudShareInvitationError) {
        self.accountAvailability = availability
        self.revokeError = revokeError
    }

    func availability() async -> ServiceAvailability { accountAvailability }
    func ensureShareRootAndCreate() async throws -> CloudShareInvitationCreateResult {
        CloudShareInvitationCreateResult(
            shareURL: URL(string: "https://icloud.com/share/unused")!,
            participantCount: 1
        )
    }
    func fetchExistingShare() async throws -> CloudShareInvitationCreateResult? { nil }
    func revokeShare() async throws { throw revokeError }
}
