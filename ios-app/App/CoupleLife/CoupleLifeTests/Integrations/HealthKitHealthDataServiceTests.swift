import SwiftData
import XCTest
@testable import CoupleLife

@MainActor
final class HealthKitHealthDataServiceTests: XCTestCase {
    func testAvailabilityReturnsNotAuthorizedWhenHealthKitShouldRequestAuthorization() async throws {
        let service = makeService(
            client: FakeHealthKitClient(
                isHealthDataAvailable: true,
                requestStatus: .shouldRequest
            )
        )

        let availability = await service.availability()

        XCTAssertEqual(availability, .notAuthorized)
    }

    func testRefreshTodaySnapshotUsesFreshDayCacheWithoutQueryingHealthKit() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let dayStart = calendar.startOfDay(for: now)
        let repository = try makeRepository()
        try repository.upsert(
            HealthMetricSnapshot(
                dayStart: dayStart,
                ownerUserId: "u1",
                steps: 3456,
                sleepSeconds: 6 * 3600,
                createdAt: now,
                updatedAt: now
            )
        )

        let client = FakeHealthKitClient(
            isHealthDataAvailable: true,
            requestStatus: .unnecessary,
            metricPayload: .init(steps: 8000, sleepSeconds: 7.5 * 3600)
        )
        let service = makeService(client: client, repository: repository, calendar: calendar, now: now)

        let availability = await service.refreshTodaySnapshot(ownerUserId: "u1", asOf: now, force: false)
        let snapshot = try repository.snapshot(dayStart: dayStart, ownerUserId: "u1")

        XCTAssertEqual(availability, .available)
        XCTAssertEqual(client.readMetricsCallCount, 0)
        XCTAssertEqual(snapshot?.steps, 3456)
        XCTAssertEqual(snapshot?.sleepSeconds, 6 * 3600)
    }

    func testRefreshTodaySnapshotQueriesHealthKitAndUpsertsSnapshotWhenCacheIsStale() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let staleDate = now.addingTimeInterval(-2 * 24 * 3600)
        let repository = try makeRepository()
        let client = FakeHealthKitClient(
            isHealthDataAvailable: true,
            requestStatus: .unnecessary,
            metricPayload: .init(steps: 8123, sleepSeconds: 7.25 * 3600)
        )
        let service = makeService(client: client, repository: repository, calendar: calendar, now: now)

        let availability = await service.refreshTodaySnapshot(ownerUserId: "u1", asOf: staleDate, force: true)
        let snapshot = try repository.snapshot(dayStart: calendar.startOfDay(for: staleDate), ownerUserId: "u1")

        XCTAssertEqual(availability, .available)
        XCTAssertEqual(client.readMetricsCallCount, 1)
        XCTAssertEqual(snapshot?.steps, 8123)
        XCTAssertEqual(snapshot?.sleepSeconds, 7.25 * 3600)
        XCTAssertEqual(snapshot?.source, .healthKit)
    }

    private func makeService(
        client: FakeHealthKitClient,
        repository: HealthSnapshotRepository? = nil,
        calendar: Calendar = Calendar(identifier: .gregorian),
        now: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> HealthKitHealthDataService {
        HealthKitHealthDataService(
            repository: repository ?? (try! makeRepository()),
            client: client,
            calendar: calendar,
            nowProvider: { now }
        )
    }

    private func makeRepository() throws -> SwiftDataHealthSnapshotRepository {
        let schema = Schema([Record.self, TaskItem.self, HealthMetricSnapshot.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        return SwiftDataHealthSnapshotRepository(context: context)
    }
}

private final class FakeHealthKitClient: HealthKitClient {
    let isHealthDataAvailable: Bool
    var requestStatus: HealthKitAuthorizationRequestStatus
    var metricPayload: HealthMetricPayload
    private(set) var readMetricsCallCount = 0

    init(
        isHealthDataAvailable: Bool,
        requestStatus: HealthKitAuthorizationRequestStatus,
        metricPayload: HealthMetricPayload = .init(steps: nil, sleepSeconds: nil)
    ) {
        self.isHealthDataAvailable = isHealthDataAvailable
        self.requestStatus = requestStatus
        self.metricPayload = metricPayload
    }

    func requestAuthorizationStatus() async throws -> HealthKitAuthorizationRequestStatus {
        requestStatus
    }

    func requestAuthorization() async throws {}

    func readMetrics(from startDate: Date, to endDate: Date) async throws -> HealthMetricPayload {
        readMetricsCallCount += 1
        return metricPayload
    }
}
