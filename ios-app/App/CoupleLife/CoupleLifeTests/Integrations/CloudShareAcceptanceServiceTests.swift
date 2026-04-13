import XCTest
@testable import CoupleLife

final class CloudShareAcceptanceServiceTests: XCTestCase {
    func testAcceptShareFailsForNonHTTPSURL() async {
        let client = BlockingCloudKitShareClient(accountAvailability: .available)
        let service = DefaultCloudShareAcceptanceService(client: client)

        let status = await service.acceptShare(from: URL(string: "http://example.com/share/abc")!)

        XCTAssertEqual(status.state, .failed)
        XCTAssertEqual(status.lastErrorCode, "invalid_scheme")
    }

    func testAcceptShareFailsForUnsupportedHostWhenWhitelistProvided() async {
        let client = BlockingCloudKitShareClient(accountAvailability: .available)
        let service = DefaultCloudShareAcceptanceService(
            client: client,
            allowedHosts: ["icloud.com"]
        )

        let status = await service.acceptShare(from: URL(string: "https://example.com/share/abc")!)

        XCTAssertEqual(status.state, .failed)
        XCTAssertEqual(status.lastErrorCode, "unsupported_host")
    }

    func testAcceptShareTransitionsToProcessingWhileClientIsInFlight() async {
        let client = BlockingCloudKitShareClient(accountAvailability: .available)
        let service = DefaultCloudShareAcceptanceService(client: client)
        let url = URL(string: "https://icloud.com/share/abc")!

        let task = Task { await service.acceptShare(from: url) }

        await client.waitUntilAcceptStarts()
        let midStatus = await service.currentStatus()
        XCTAssertEqual(midStatus.state, .processing)

        await client.finishAcceptSuccessfully()
        let finalStatus = await task.value
        XCTAssertEqual(finalStatus.state, .accepted)
        XCTAssertEqual(finalStatus.lastErrorCode, nil)
        XCTAssertEqual(finalStatus.lastURL, url)
    }

    func testAcceptShareSurfacesStableErrorCodeFromClient() async {
        let client = FailingCloudKitShareClient(
            accountAvailability: .available,
            error: CloudShareAcceptanceError(code: "ck_not_authenticated")
        )
        let service = DefaultCloudShareAcceptanceService(client: client)

        let status = await service.acceptShare(from: URL(string: "https://icloud.com/share/abc")!)

        XCTAssertEqual(status.state, .failed)
        XCTAssertEqual(status.lastErrorCode, "ck_not_authenticated")
    }

    func testAcceptShareFailsFastWhenServiceIsNotAuthorized() async {
        let client = BlockingCloudKitShareClient(accountAvailability: .notAuthorized)
        let service = DefaultCloudShareAcceptanceService(client: client)

        let status = await service.acceptShare(from: URL(string: "https://icloud.com/share/abc")!)

        XCTAssertEqual(status.availability, .notAuthorized)
        XCTAssertEqual(status.state, .failed)
        XCTAssertEqual(status.lastErrorCode, "not_authorized")
    }
}

private actor BlockingCloudKitShareClient: CloudKitShareClient {
    private let accountAvailability: ServiceAvailability
    private var didStartAccept = false
    private var continuation: CheckedContinuation<Void, Never>?

    init(accountAvailability: ServiceAvailability) {
        self.accountAvailability = accountAvailability
    }

    func availability() async -> ServiceAvailability {
        accountAvailability
    }

    func acceptShare(from url: URL) async throws {
        didStartAccept = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.continuation = continuation
        }
    }

    func waitUntilAcceptStarts() async {
        while !didStartAccept {
            await Task.yield()
        }
    }

    func finishAcceptSuccessfully() async {
        continuation?.resume()
        continuation = nil
    }
}

private actor FailingCloudKitShareClient: CloudKitShareClient {
    private let accountAvailability: ServiceAvailability
    private let error: CloudShareAcceptanceError

    init(accountAvailability: ServiceAvailability, error: CloudShareAcceptanceError) {
        self.accountAvailability = accountAvailability
        self.error = error
    }

    func availability() async -> ServiceAvailability {
        accountAvailability
    }

    func acceptShare(from url: URL) async throws {
        throw error
    }
}

