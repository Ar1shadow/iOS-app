import HealthKit
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

    func testAvailabilityReturnsAvailableWhenRequestStatusIsUnnecessary() async throws {
        let service = makeService(
            client: FakeHealthKitClient(
                isHealthDataAvailable: true,
                requestStatus: .unnecessary
            )
        )

        let availability = await service.availability()

        XCTAssertEqual(availability, .available)
    }

    func testRefreshTodaySnapshotReturnsFailedWhenHealthKitReadErrors() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let client = FakeHealthKitClient(
            isHealthDataAvailable: true,
            requestStatus: .unnecessary,
            readMetricsError: NSError(
                domain: HKErrorDomain,
                code: HKError.Code.errorAuthorizationDenied.rawValue
            )
        )
        let service = makeService(client: client, calendar: calendar, now: now)

        let availability = await service.refreshTodaySnapshot(ownerUserId: "u1", asOf: now, force: true)

        XCTAssertEqual(availability, .failed("健康数据刷新失败，请稍后重试。"))
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
            metricPayload: .init(
                steps: 8000,
                distanceMeters: 5_200,
                activeEnergyKcal: 420,
                exerciseMinutes: 38,
                standMinutes: 600,
                sleepSeconds: 7.5 * 3600,
                restingHeartRate: nil
            )
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
                calendar.startOfDay(for: staleDate): .init(
                    steps: 8123,
                    distanceMeters: 6_400,
                    activeEnergyKcal: 510,
                    exerciseMinutes: 44,
                    standMinutes: 720,
                    sleepSeconds: 7.25 * 3600,
                    restingHeartRate: 54
                ),
                calendar.dateInterval(of: .weekOfYear, for: staleDate)!.start: .init(
                    steps: 42_000,
                    distanceMeters: 31_000,
                    activeEnergyKcal: 2_840,
                    exerciseMinutes: 260,
                    standMinutes: 4_200,
                    sleepSeconds: 46 * 3600,
                    restingHeartRate: 56
                ),
                calendar.dateInterval(of: .month, for: staleDate)!.start: .init(
                    steps: 160_000,
                    distanceMeters: 118_000,
                    activeEnergyKcal: 10_400,
                    exerciseMinutes: 1_040,
                    standMinutes: 17_600,
                    sleepSeconds: 180 * 3600,
                    restingHeartRate: 58
                )
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
        XCTAssertEqual(daySnapshot?.distanceMeters, 6_400)
        XCTAssertEqual(daySnapshot?.activeEnergyKcal, 510)
        XCTAssertEqual(daySnapshot?.exerciseMinutes, 44)
        XCTAssertEqual(daySnapshot?.standMinutes, 720)
        XCTAssertEqual(daySnapshot?.sleepSeconds, 7.25 * 3600)
        XCTAssertEqual(daySnapshot?.restingHeartRate, 54)
        XCTAssertEqual(daySnapshot?.source, .healthKit)
        XCTAssertEqual(daySnapshot?.bucket, .day)
        XCTAssertEqual(weekSnapshot?.steps, 42_000)
        XCTAssertEqual(weekSnapshot?.distanceMeters, 31_000)
        XCTAssertEqual(weekSnapshot?.activeEnergyKcal, 2_840)
        XCTAssertEqual(weekSnapshot?.exerciseMinutes, 260)
        XCTAssertEqual(weekSnapshot?.standMinutes, 4_200)
        XCTAssertEqual(weekSnapshot?.restingHeartRate, 56)
        XCTAssertEqual(weekSnapshot?.bucket, .week)
        XCTAssertEqual(monthSnapshot?.steps, 160_000)
        XCTAssertEqual(monthSnapshot?.distanceMeters, 118_000)
        XCTAssertEqual(monthSnapshot?.activeEnergyKcal, 10_400)
        XCTAssertEqual(monthSnapshot?.exerciseMinutes, 1_040)
        XCTAssertEqual(monthSnapshot?.standMinutes, 17_600)
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
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        return SwiftDataHealthSnapshotRepository(context: context)
    }
}

private final class FakeHealthKitClient: HealthKitClient {
    let isHealthDataAvailable: Bool
    var requestStatus: HealthKitAuthorizationRequestStatus
    var metricPayloadByStartDate: [Date: HealthMetricPayload]
    var readMetricsError: Error?
    private(set) var readMetricsCallCount = 0

    init(
        isHealthDataAvailable: Bool,
        requestStatus: HealthKitAuthorizationRequestStatus,
        metricPayload: HealthMetricPayload = .init(
            steps: nil,
            distanceMeters: nil,
            activeEnergyKcal: nil,
            exerciseMinutes: nil,
            standMinutes: nil,
            sleepSeconds: nil,
            restingHeartRate: nil
        ),
        metricPayloadByStartDate: [Date: HealthMetricPayload] = [:],
        readMetricsError: Error? = nil
    ) {
        self.isHealthDataAvailable = isHealthDataAvailable
        self.requestStatus = requestStatus
        self.readMetricsError = readMetricsError
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
        if let readMetricsError {
            throw readMetricsError
        }
        return metricPayloadByStartDate[startDate] ?? metricPayloadByStartDate[Date.distantPast]!
    }
}
