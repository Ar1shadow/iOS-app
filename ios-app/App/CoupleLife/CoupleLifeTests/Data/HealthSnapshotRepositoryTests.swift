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
}
