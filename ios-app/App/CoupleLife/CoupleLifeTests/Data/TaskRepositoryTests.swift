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

    func testFetchScheduledTasksByDateRangeAndOwner() throws {
        let schema = Schema([Record.self, TaskItem.self, HealthMetricSnapshot.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let repo = SwiftDataTaskRepository(context: context)

        let calendar = Calendar(identifier: .gregorian)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let dayStart = calendar.startOfDay(for: base)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let dueInRange = calendar.date(byAdding: .hour, value: 10, to: dayStart)!
        let dueOutOfRange = calendar.date(byAdding: .day, value: 2, to: dayStart)!

        try repo.create(TaskItem(title: "in-range-todo", dueAt: dueInRange, status: .todo, ownerUserId: "u1"))
        try repo.create(TaskItem(title: "in-range-done", dueAt: dueInRange, status: .done, ownerUserId: "u1"))
        try repo.create(TaskItem(title: "out-of-range", dueAt: dueOutOfRange, status: .todo, ownerUserId: "u1"))
        try repo.create(TaskItem(title: "other-owner", dueAt: dueInRange, status: .todo, ownerUserId: "u2"))

        let allScheduled = try repo.tasks(scheduledFrom: dayStart, to: dayEnd, ownerUserId: "u1", status: nil)
        XCTAssertEqual(Set(allScheduled.map(\.title)), Set(["in-range-todo", "in-range-done"]))

        let scheduledTodo = try repo.tasks(scheduledFrom: dayStart, to: dayEnd, ownerUserId: "u1", status: .todo)
        XCTAssertEqual(scheduledTodo.map(\.title), ["in-range-todo"])
    }

    func testUpdatePersistsEditedFieldsAndBumpsVersion() throws {
        let schema = Schema([Record.self, TaskItem.self, HealthMetricSnapshot.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let initialDate = Date(timeIntervalSince1970: 2_000)
        let updatedDate = initialDate.addingTimeInterval(3_600)
        let repo = SwiftDataTaskRepository(context: context, nowProvider: { updatedDate })

        let task = TaskItem(
            title: "原任务",
            detail: "原备注",
            dueAt: initialDate,
            status: .todo,
            planLevel: .day,
            ownerUserId: "u1",
            createdAt: initialDate,
            updatedAt: initialDate
        )
        try repo.create(task)

        task.title = "已延期任务"
        task.detail = "改为明天处理"
        task.planLevel = .week
        task.status = .postponed
        task.dueAt = updatedDate
        try repo.update(task)

        let tasks = try repo.tasks(status: .postponed)
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.title, "已延期任务")
        XCTAssertEqual(tasks.first?.detail, "改为明天处理")
        XCTAssertEqual(tasks.first?.planLevel, .week)
        XCTAssertEqual(tasks.first?.dueAt, updatedDate)
        XCTAssertEqual(tasks.first?.version, 2)
        XCTAssertEqual(tasks.first?.updatedAt, updatedDate)
    }
}
