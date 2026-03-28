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
            metricPayload: .init(steps: 8000, sleepSeconds: 7.5 * 3600, restingHeartRate: nil)
        )
        let service = makeService(client: client, repository: repository, calendar: calendar, now: now)

        let availability = await service.refreshTodaySnapshot(ownerUserId: "u1", asOf: now, force: false)
        let snapshot = try repository.snapshot(dayStart: dayStart, ownerUserId: "u1")

        XCTAssertEqual(availability, ServiceAvailability.available)
        XCTAssertEqual(client.readMetricsCallCount, 0)
        XCTAssertEqual(snapshot?.steps, 3456)
        XCTAssertEqual(snapshot?.sleepSeconds, 6 * 3600)
    }

    func testRefreshTodaySnapshotQueriesHealthKitAndUpsertsSnapshotWhenCacheIsStale() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let staleDate = calendar.date(from: DateComponents(year: 2024, month: 11, day: 20, hour: 12))!
        let now = staleDate.addingTimeInterval(2 * 24 * 3600)
        let repository = try makeRepository()
        let client = FakeHealthKitClient(
            isHealthDataAvailable: true,
            requestStatus: .unnecessary,
            metricPayloadByStartDate: [
                calendar.startOfDay(for: staleDate): .init(steps: 8123, sleepSeconds: 7.25 * 3600, restingHeartRate: 54),
                calendar.dateInterval(of: .weekOfYear, for: staleDate)!.start: .init(steps: 42_000, sleepSeconds: 46 * 3600, restingHeartRate: 56),
                calendar.dateInterval(of: .month, for: staleDate)!.start: .init(steps: 160_000, sleepSeconds: 180 * 3600, restingHeartRate: 58)
            ]
        )
        let service = makeService(client: client, repository: repository, calendar: calendar, now: now)

        let availability = await service.refreshTodaySnapshot(ownerUserId: "u1", asOf: staleDate, force: true)
        let dayStart = calendar.startOfDay(for: staleDate)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: staleDate)!.start
        let monthStart = calendar.dateInterval(of: .month, for: staleDate)!.start
        let daySnapshot = try repository.snapshot(dayStart: dayStart, ownerUserId: "u1")
        let weekSnapshot = try repository.snapshot(bucket: .week, start: weekStart, ownerUserId: "u1")
        let monthSnapshot = try repository.snapshot(bucket: .month, start: monthStart, ownerUserId: "u1")

        XCTAssertEqual(availability, ServiceAvailability.available)
        XCTAssertEqual(client.readMetricsCallCount, 3)
        XCTAssertEqual(daySnapshot?.steps, 8123)
        XCTAssertEqual(daySnapshot?.sleepSeconds, 7.25 * 3600)
        XCTAssertEqual(daySnapshot?.restingHeartRate, 54)
        XCTAssertEqual(daySnapshot?.source, .healthKit)
        XCTAssertEqual(daySnapshot?.bucket, .day)
        XCTAssertEqual(weekSnapshot?.steps, 42_000)
        XCTAssertEqual(weekSnapshot?.restingHeartRate, 56)
        XCTAssertEqual(weekSnapshot?.bucket, .week)
        XCTAssertEqual(monthSnapshot?.steps, 160_000)
        XCTAssertEqual(monthSnapshot?.restingHeartRate, 58)
        XCTAssertEqual(monthSnapshot?.bucket, .month)
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
    var metricPayloadByStartDate: [Date: HealthMetricPayload]
    private(set) var readMetricsCallCount = 0

    init(
        isHealthDataAvailable: Bool,
        requestStatus: HealthKitAuthorizationRequestStatus,
        metricPayload: HealthMetricPayload = .init(steps: nil, sleepSeconds: nil, restingHeartRate: nil),
        metricPayloadByStartDate: [Date: HealthMetricPayload] = [:]
    ) {
        self.isHealthDataAvailable = isHealthDataAvailable
        self.requestStatus = requestStatus
        if metricPayloadByStartDate.isEmpty {
            self.metricPayloadByStartDate = [Date.distantPast: metricPayload]
        } else {
            self.metricPayloadByStartDate = metricPayloadByStartDate
        }
    }

    func requestAuthorizationStatus() async throws -> HealthKitAuthorizationRequestStatus {
        requestStatus
    }

    func requestAuthorization() async throws {}

    func readMetrics(from startDate: Date, to endDate: Date) async throws -> HealthMetricPayload {
        readMetricsCallCount += 1
        return metricPayloadByStartDate[startDate] ?? metricPayloadByStartDate[Date.distantPast]!
    }
}
