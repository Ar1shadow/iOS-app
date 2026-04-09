import SwiftData
import XCTest
@testable import CoupleLife

final class RecordRepositoryTests: XCTestCase {
    func testCreateAndFetchByDateRange() throws {
        let schema = Schema([Record.self, TaskItem.self, HealthMetricSnapshot.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let repo = SwiftDataRecordRepository(context: context)

        let start = Date(timeIntervalSince1970: 0)
        let record = Record(type: .water, note: nil, startAt: start.addingTimeInterval(60), ownerUserId: "u1")
        try repo.create(record)

        let results = try repo.records(from: start, to: start.addingTimeInterval(3600))
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.type, .water)
    }

    func testUpdatePersistsEditedFieldsAndBumpsVersion() throws {
        let schema = Schema([Record.self, TaskItem.self, HealthMetricSnapshot.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let initialDate = Date(timeIntervalSince1970: 1_000)
        let updatedDate = initialDate.addingTimeInterval(600)
        let repo = SwiftDataRecordRepository(context: context, nowProvider: { updatedDate })

        let record = Record(
            type: .water,
            note: "Before workout",
            tagsRaw: "hydration",
            startAt: initialDate,
            ownerUserId: "u1",
            createdAt: initialDate,
            updatedAt: initialDate
        )
        try repo.create(record)

        record.note = "After workout"
        record.tags = ["hydration", "post-gym"]
        record.valueText = "500ml"
        record.endAt = updatedDate
        try repo.update(record)

        let results = try repo.records(from: initialDate.addingTimeInterval(-60), to: updatedDate.addingTimeInterval(60))
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.note, "After workout")
        XCTAssertEqual(results.first?.tags, ["hydration", "post-gym"])
        XCTAssertEqual(results.first?.valueText, "500ml")
        XCTAssertEqual(results.first?.endAt, updatedDate)
        XCTAssertEqual(results.first?.version, 2)
        XCTAssertEqual(results.first?.updatedAt, updatedDate)
    }
}
