import XCTest
@testable import CoupleLife

final class FitnessDashboardServiceTests: XCTestCase {
    func testLoadMarksBackgroundRefreshNeededWhenWeekSummaryIsMissing() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let dayStart = calendar.startOfDay(for: now)
        let monthStart = calendar.dateInterval(of: .month, for: now)!.start
        let repository = InMemoryFitnessHealthSnapshotRepository(
            snapshots: [
                HealthMetricSnapshot(dayStart: dayStart, ownerUserId: "u1", bucket: .day, steps: 1000, updatedAt: now),
                HealthMetricSnapshot(dayStart: monthStart, ownerUserId: "u1", bucket: .month, steps: 30_000, updatedAt: now)
            ]
        )
        let service = DefaultFitnessDashboardService(
            repository: repository,
            calendar: calendar,
            nowProvider: { now }
        )

        let content = try service.load(ownerUserId: "u1", asOf: now)

        XCTAssertTrue(content.needsBackgroundRefresh)
    }

    func testLoadDoesNotMarkBackgroundRefreshWhenCurrentBucketsExistAndDayIsFresh() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let dayStart = calendar.startOfDay(for: now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let monthStart = calendar.dateInterval(of: .month, for: now)!.start
        let repository = InMemoryFitnessHealthSnapshotRepository(
            snapshots: [
                HealthMetricSnapshot(dayStart: dayStart, ownerUserId: "u1", bucket: .day, steps: 1000, updatedAt: now),
                HealthMetricSnapshot(dayStart: weekStart, ownerUserId: "u1", bucket: .week, steps: 7_000, updatedAt: now),
                HealthMetricSnapshot(dayStart: monthStart, ownerUserId: "u1", bucket: .month, steps: 30_000, updatedAt: now)
            ]
        )
        let service = DefaultFitnessDashboardService(
            repository: repository,
            calendar: calendar,
            nowProvider: { now }
        )

        let content = try service.load(ownerUserId: "u1", asOf: now)

        XCTAssertFalse(content.needsBackgroundRefresh)
    }
}

private final class InMemoryFitnessHealthSnapshotRepository: HealthSnapshotRepository {
    private let snapshotsStore: [HealthMetricSnapshot]

    init(snapshots: [HealthMetricSnapshot]) {
        self.snapshotsStore = snapshots
    }

    func upsert(_ snapshot: HealthMetricSnapshot) throws {}

    func snapshot(bucket: HealthMetricBucket, start: Date, ownerUserId: String) throws -> HealthMetricSnapshot? {
        snapshotsStore.first {
            $0.bucket == bucket && $0.dayStart == start && $0.ownerUserId == ownerUserId
        }
    }

    func snapshot(dayStart: Date, ownerUserId: String) throws -> HealthMetricSnapshot? {
        try snapshot(bucket: .day, start: dayStart, ownerUserId: ownerUserId)
    }

    func snapshots(bucket: HealthMetricBucket, from startDate: Date, to endDate: Date, ownerUserId: String) throws -> [HealthMetricSnapshot] {
        snapshotsStore
            .filter { $0.bucket == bucket && $0.ownerUserId == ownerUserId }
            .filter { $0.dayStart >= startDate && $0.dayStart < endDate }
            .sorted { $0.dayStart < $1.dayStart }
    }
}
