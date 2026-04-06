import SwiftData
import XCTest
@testable import CoupleLife

final class HealthSnapshotRepositoryTests: XCTestCase {
    func testUpsertSeparatesDayWeekAndMonthBuckets() throws {
        let schema = Schema([Record.self, TaskItem.self, HealthMetricSnapshot.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let repository = SwiftDataHealthSnapshotRepository(context: context)
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        try repository.upsert(
            HealthMetricSnapshot(
                dayStart: start,
                ownerUserId: "u1",
                bucket: .day,
                steps: 1000
            )
        )
        try repository.upsert(
            HealthMetricSnapshot(
                dayStart: start,
                ownerUserId: "u1",
                bucket: .week,
                steps: 7000
            )
        )
        try repository.upsert(
            HealthMetricSnapshot(
                dayStart: start,
                ownerUserId: "u1",
                bucket: .month,
                steps: 30000
            )
        )

        let daySnapshot = try repository.snapshot(dayStart: start, ownerUserId: "u1")
        let weekSnapshot = try repository.snapshot(bucket: .week, start: start, ownerUserId: "u1")
        let monthSnapshot = try repository.snapshot(bucket: .month, start: start, ownerUserId: "u1")

        XCTAssertEqual(daySnapshot?.steps, 1000)
        XCTAssertEqual(daySnapshot?.bucket, .day)
        XCTAssertEqual(weekSnapshot?.steps, 7000)
        XCTAssertEqual(weekSnapshot?.bucket, .week)
        XCTAssertEqual(monthSnapshot?.steps, 30000)
        XCTAssertEqual(monthSnapshot?.bucket, .month)
    }

    func testSnapshotsReturnsSortedRangeFilteredByBucketOwnerAndDate() throws {
        let schema = Schema([Record.self, TaskItem.self, HealthMetricSnapshot.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let repository = SwiftDataHealthSnapshotRepository(context: context)
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let secondDay = calendar.date(byAdding: .day, value: 1, to: start)!
        let thirdDay = calendar.date(byAdding: .day, value: 2, to: start)!
        let fourthDay = calendar.date(byAdding: .day, value: 3, to: start)!

        try repository.upsert(HealthMetricSnapshot(dayStart: thirdDay, ownerUserId: "u1", bucket: .day, steps: 3000))
        try repository.upsert(HealthMetricSnapshot(dayStart: start, ownerUserId: "u1", bucket: .day, steps: 1000))
        try repository.upsert(HealthMetricSnapshot(dayStart: secondDay, ownerUserId: "u1", bucket: .day, steps: 2000))
        try repository.upsert(HealthMetricSnapshot(dayStart: secondDay, ownerUserId: "u2", bucket: .day, steps: 9000))
        try repository.upsert(HealthMetricSnapshot(dayStart: secondDay, ownerUserId: "u1", bucket: .week, steps: 7000))

        let snapshots = try repository.snapshots(
            bucket: .day,
            from: start,
            to: fourthDay,
            ownerUserId: "u1"
        )

        XCTAssertEqual(snapshots.map(\.dayStart), [start, secondDay, thirdDay])
        XCTAssertEqual(snapshots.map(\.steps), [1000, 2000, 3000])
    }
}
