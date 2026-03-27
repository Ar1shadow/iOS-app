import SwiftData
import XCTest
@testable import CoupleLife

final class TaskRepositoryTests: XCTestCase {
    func testCreateAndFetchByStatus() throws {
        let schema = Schema([Record.self, TaskItem.self, HealthMetricSnapshot.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let repo = SwiftDataTaskRepository(context: context)

        let t1 = TaskItem(title: "t1", status: .todo, ownerUserId: "u1")
        let t2 = TaskItem(title: "t2", status: .done, ownerUserId: "u1")
        try repo.create(t1)
        try repo.create(t2)

        let todos = try repo.tasks(status: .todo)
        XCTAssertEqual(todos.count, 1)
        XCTAssertEqual(todos.first?.title, "t1")
    }
}

