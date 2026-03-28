import XCTest
@testable import CoupleLife

final class PlanningTaskServiceTests: XCTestCase {
    func testLoadTasksReturnsCurrentOwnerTasksSortedBySchedule() throws {
        let calendar = Calendar(identifier: .gregorian)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let today = calendar.startOfDay(for: base)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: today)!

        let repository = InMemoryPlanningTaskRepository(tasks: [
            TaskItem(title: "未排期", status: .todo, planLevel: .month, ownerUserId: "local", updatedAt: base),
            TaskItem(title: "明天任务", dueAt: tomorrow, status: .todo, planLevel: .day, ownerUserId: "local", updatedAt: base),
            TaskItem(title: "下周任务", dueAt: nextWeek, status: .todo, planLevel: .week, ownerUserId: "local", updatedAt: base),
            TaskItem(title: "他人任务", dueAt: today, status: .todo, planLevel: .day, ownerUserId: "other", updatedAt: base)
        ])
        let service = DefaultPlanningTaskService(taskRepository: repository, ownerUserId: "local", calendar: calendar)

        let tasks = try service.loadTasks()

        XCTAssertEqual(tasks.map(\.title), ["明天任务", "下周任务", "未排期"])
    }

    func testCreateTaskRejectsBlankTitle() {
        let repository = InMemoryPlanningTaskRepository(tasks: [])
        let service = DefaultPlanningTaskService(taskRepository: repository, ownerUserId: "local")

        XCTAssertThrowsError(
            try service.createTask(
                from: PlanningTaskDraft(
                    title: "   ",
                    detail: "",
                    planLevel: .day,
                    status: .todo,
                    startAt: nil,
                    dueAt: nil,
                    isAllDay: false
                )
            )
        ) { error in
            XCTAssertEqual(error as? PlanningTaskValidationError, .emptyTitle)
        }
    }

    func testCreateTaskAlwaysStartsAsTodo() throws {
        let repository = InMemoryPlanningTaskRepository(tasks: [])
        let service = DefaultPlanningTaskService(taskRepository: repository, ownerUserId: "local")

        let created = try service.createTask(
            from: PlanningTaskDraft(
                title: "新任务",
                detail: "",
                planLevel: .day,
                status: .done,
                startAt: nil,
                dueAt: nil,
                isAllDay: false
            )
        )

        XCTAssertEqual(created.status, .todo)
        XCTAssertEqual(repository.createdTasks.map(\.status), [.todo])
    }

    func testUpdateTaskDoesNotAllowEditingIntoDoneState() throws {
        let repository = InMemoryPlanningTaskRepository(tasks: [])
        let service = DefaultPlanningTaskService(taskRepository: repository, ownerUserId: "local")
        let task = TaskItem(title: "产检预约", status: .todo, planLevel: .day, ownerUserId: "local")

        XCTAssertThrowsError(
            try service.updateTask(
                task,
                from: PlanningTaskDraft(
                    title: "产检预约",
                    detail: "改备注",
                    planLevel: .week,
                    status: .done,
                    startAt: nil,
                    dueAt: nil,
                    isAllDay: false
                )
            )
        ) { error in
            XCTAssertEqual(error as? PlanningTaskValidationError, .invalidStatusTransition)
        }
        XCTAssertEqual(task.status, .todo)
    }

    func testPostponeMovesScheduledDatesForwardOneDayAndMarksTaskPostponed() throws {
        let calendar = Calendar(identifier: .gregorian)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let startAt = calendar.date(byAdding: .hour, value: 9, to: base)!
        let dueAt = calendar.date(byAdding: .hour, value: 10, to: base)!

        let repository = InMemoryPlanningTaskRepository(tasks: [])
        let service = DefaultPlanningTaskService(taskRepository: repository, ownerUserId: "local", calendar: calendar)
        let task = TaskItem(
            title: "产检预约",
            startAt: startAt,
            dueAt: dueAt,
            status: .todo,
            planLevel: .day,
            ownerUserId: "local"
        )

        try service.postponeTask(task)

        XCTAssertEqual(task.status, .postponed)
        XCTAssertEqual(task.startAt, calendar.date(byAdding: .day, value: 1, to: startAt))
        XCTAssertEqual(task.dueAt, calendar.date(byAdding: .day, value: 1, to: dueAt))
        XCTAssertEqual(repository.updatedTaskIDs, [task.id])
    }

    func testCancelTaskRejectsCompletedTask() throws {
        let repository = InMemoryPlanningTaskRepository(tasks: [])
        let service = DefaultPlanningTaskService(taskRepository: repository, ownerUserId: "local")
        let task = TaskItem(title: "已完成任务", status: .done, planLevel: .day, ownerUserId: "local")

        XCTAssertThrowsError(try service.cancelTask(task)) { error in
            XCTAssertEqual(error as? PlanningTaskValidationError, .invalidStatusTransition)
        }
        XCTAssertTrue(repository.updatedTaskIDs.isEmpty)
    }

    func testCreateTaskSyncsToCalendarWhenEnabledAndPersistsEventIdentifier() throws {
        let repository = InMemoryPlanningTaskRepository(tasks: [])
        let calendarSync = TestCalendarSyncService()
        calendarSync.upsertedEventIdentifier = "event-123"
        let settings = TestCalendarSyncSettingsStore(isEnabled: true)
        let service = DefaultPlanningTaskService(
            taskRepository: repository,
            ownerUserId: "local",
            calendarSyncService: calendarSync,
            calendarSyncSettings: settings
        )

        let created = try service.createTask(
            from: PlanningTaskDraft(
                title: "产检预约",
                detail: "门诊楼三层",
                planLevel: .day,
                status: .todo,
                startAt: Date(timeIntervalSince1970: 1_700_000_000),
                dueAt: Date(timeIntervalSince1970: 1_700_003_600),
                isAllDay: false
            )
        )

        XCTAssertEqual(calendarSync.upsertedTaskTitles, ["产检预约"])
        XCTAssertEqual(created.systemCalendarEventId, "event-123")
        XCTAssertEqual(repository.createdTasks.first?.systemCalendarEventId, "event-123")
    }

    func testUpdateTaskSkipsCalendarSyncWhenDisabled() throws {
        let repository = InMemoryPlanningTaskRepository(tasks: [])
        let calendarSync = TestCalendarSyncService()
        let settings = TestCalendarSyncSettingsStore(isEnabled: false)
        let service = DefaultPlanningTaskService(
            taskRepository: repository,
            ownerUserId: "local",
            calendarSyncService: calendarSync,
            calendarSyncSettings: settings
        )
        let task = TaskItem(title: "产检预约", status: .todo, planLevel: .day, ownerUserId: "local")

        try service.updateTask(
            task,
            from: PlanningTaskDraft(
                title: "产检预约（更新）",
                detail: "",
                planLevel: .day,
                status: .todo,
                startAt: nil,
                dueAt: nil,
                isAllDay: false
            )
        )

        XCTAssertTrue(calendarSync.upsertedTaskTitles.isEmpty)
        XCTAssertEqual(repository.updatedTaskIDs, [task.id])
    }

    func testUpdateTaskKeepsCrudWorkingWhenCalendarSyncFails() throws {
        let repository = InMemoryPlanningTaskRepository(tasks: [])
        let calendarSync = TestCalendarSyncService()
        calendarSync.upsertError = CalendarSyncError.operationFailed("save failed")
        let settings = TestCalendarSyncSettingsStore(isEnabled: true)
        let service = DefaultPlanningTaskService(
            taskRepository: repository,
            ownerUserId: "local",
            calendarSyncService: calendarSync,
            calendarSyncSettings: settings
        )
        let task = TaskItem(title: "产检预约", status: .todo, planLevel: .day, ownerUserId: "local")

        try service.updateTask(
            task,
            from: PlanningTaskDraft(
                title: "产检预约（更新）",
                detail: "",
                planLevel: .day,
                status: .todo,
                startAt: nil,
                dueAt: nil,
                isAllDay: false
            )
        )

        XCTAssertEqual(task.title, "产检预约（更新）")
        XCTAssertNil(task.systemCalendarEventId)
        XCTAssertEqual(repository.updatedTaskIDs, [task.id])
    }

    func testDeleteTaskDeletesLinkedCalendarEventBeforeRemovingTask() throws {
        let repository = InMemoryPlanningTaskRepository(tasks: [])
        let calendarSync = TestCalendarSyncService()
        let settings = TestCalendarSyncSettingsStore(isEnabled: true)
        repository.onDelete = { task in
            calendarSync.operationLog.append(.deleteTask(task.id))
        }
        let service = DefaultPlanningTaskService(
            taskRepository: repository,
            ownerUserId: "local",
            calendarSyncService: calendarSync,
            calendarSyncSettings: settings
        )
        let task = TaskItem(
            title: "产检预约",
            status: .todo,
            planLevel: .day,
            ownerUserId: "local",
            systemCalendarEventId: "event-123"
        )

        try service.deleteTask(task)

        XCTAssertEqual(calendarSync.deletedEventIdentifiers, ["event-123"])
        XCTAssertEqual(repository.deletedTaskIDs, [task.id])
        XCTAssertEqual(calendarSync.operationLog, [.deleteEvent("event-123"), .deleteTask(task.id)])
    }
}

private final class InMemoryPlanningTaskRepository: TaskRepository {
    private var items: [TaskItem]
    private(set) var updatedTaskIDs: [UUID] = []
    private(set) var createdTasks: [TaskItem] = []
    private(set) var deletedTaskIDs: [UUID] = []
    var onDelete: ((TaskItem) -> Void)?

    init(tasks: [TaskItem]) {
        self.items = tasks
    }

    func create(_ task: TaskItem) throws {
        items.append(task)
        createdTasks.append(task)
    }

    func update(_ task: TaskItem) throws {
        updatedTaskIDs.append(task.id)
    }

    func delete(_ task: TaskItem) throws {
        deletedTaskIDs.append(task.id)
        onDelete?(task)
        items.removeAll { $0.id == task.id }
    }

    func tasks(status: TaskStatus?) throws -> [TaskItem] {
        guard let status else { return items }
        return items.filter { $0.status == status }
    }

    func tasks(scheduledFrom start: Date, to end: Date, ownerUserId: String, status: TaskStatus?) throws -> [TaskItem] {
        items
            .filter { $0.ownerUserId == ownerUserId }
            .filter { task in
                guard let status else { return true }
                return task.status == status
            }
            .filter { task in
                let targetDate = task.dueAt ?? task.startAt
                guard let targetDate else { return false }
                return targetDate >= start && targetDate < end
            }
    }
}
