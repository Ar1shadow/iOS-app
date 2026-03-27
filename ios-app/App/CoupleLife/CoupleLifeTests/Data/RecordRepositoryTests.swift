import SwiftData
import XCTest
@testable import CoupleLife

final class RecordRepositoryTests: XCTestCase {
    func testCreateAndFetchByDateRange() throws {
        let schema = Schema([Record.self, TaskItem.self, HealthMetricSnapshot.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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
}

