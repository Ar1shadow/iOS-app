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
        XCTAssertEqual(repository.updatedTaskIDs, [created.id])
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

    func testCreateTaskSchedulesNotificationReminderWhenEnabled() throws {
        let repository = InMemoryPlanningTaskRepository(tasks: [])
        let notificationScheduler = TestNotificationScheduler()
        let notificationSettings = TestNotificationSettingsStore(isTaskRemindersEnabled: true)
        let service = DefaultPlanningTaskService(
            taskRepository: repository,
            ownerUserId: "local",
            notificationScheduler: notificationScheduler,
            notificationSettings: notificationSettings
        )
        let dueAt = Date(timeIntervalSince1970: 1_700_003_600)
        let expectation = expectation(description: "schedule reminder")
        notificationScheduler.operationExpectation = expectation

        let created = try service.createTask(
            from: PlanningTaskDraft(
                title: "喝水提醒",
                detail: "",
                planLevel: .day,
                status: .todo,
                startAt: nil,
                dueAt: dueAt,
                isAllDay: false
            )
        )

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(
            notificationScheduler.scheduledTaskReminders,
            [.init(
                id: created.id,
                title: "喝水提醒",
                fireDate: dueAt,
                kind: .personalTask
            )]
        )
        XCTAssertTrue(notificationScheduler.cancelledTaskIDs.isEmpty)
    }

    func testUpdateTaskCancelsNotificationReminderWhenScheduleIsRemoved() throws {
        let repository = InMemoryPlanningTaskRepository(tasks: [])
        let notificationScheduler = TestNotificationScheduler()
        let notificationSettings = TestNotificationSettingsStore(isTaskRemindersEnabled: true)
        let service = DefaultPlanningTaskService(
            taskRepository: repository,
            ownerUserId: "local",
            notificationScheduler: notificationScheduler,
            notificationSettings: notificationSettings
        )
        let task = TaskItem(
            title: "产检预约",
            startAt: Date(timeIntervalSince1970: 1_700_000_000),
            dueAt: nil,
            status: .todo,
            planLevel: .day,
            ownerUserId: "local"
        )
        let expectation = expectation(description: "cancel reminder")
        notificationScheduler.operationExpectation = expectation

        try service.updateTask(
            task,
            from: PlanningTaskDraft(
                title: "产检预约",
                detail: "",
                planLevel: .day,
                status: .todo,
                startAt: nil,
                dueAt: nil,
                isAllDay: false
            )
        )

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(notificationScheduler.cancelledTaskIDs, [task.id])
        XCTAssertTrue(notificationScheduler.scheduledTaskReminders.isEmpty)
    }

    func testMarkTaskDoneCancelsNotificationReminder() throws {
        let repository = InMemoryPlanningTaskRepository(tasks: [])
        let notificationScheduler = TestNotificationScheduler()
        let notificationSettings = TestNotificationSettingsStore(isTaskRemindersEnabled: true)
        let service = DefaultPlanningTaskService(
            taskRepository: repository,
            ownerUserId: "local",
            notificationScheduler: notificationScheduler,
            notificationSettings: notificationSettings
        )
        let task = TaskItem(
            title: "产检预约",
            dueAt: Date(timeIntervalSince1970: 1_700_003_600),
            status: .todo,
            planLevel: .day,
            ownerUserId: "local"
        )
        let expectation = expectation(description: "cancel reminder")
        notificationScheduler.operationExpectation = expectation

        try service.markTaskDone(task)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(notificationScheduler.cancelledTaskIDs, [task.id])
    }

    func testDeleteTaskCancelsNotificationReminder() throws {
        let repository = InMemoryPlanningTaskRepository(tasks: [])
        let notificationScheduler = TestNotificationScheduler()
        let notificationSettings = TestNotificationSettingsStore(isTaskRemindersEnabled: true)
        let service = DefaultPlanningTaskService(
            taskRepository: repository,
            ownerUserId: "local",
            notificationScheduler: notificationScheduler,
            notificationSettings: notificationSettings
        )
        let task = TaskItem(
            title: "产检预约",
            dueAt: Date(timeIntervalSince1970: 1_700_003_600),
            status: .todo,
            planLevel: .day,
            ownerUserId: "local"
        )
        let expectation = expectation(description: "cancel reminder")
        notificationScheduler.operationExpectation = expectation

        try service.deleteTask(task)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(notificationScheduler.cancelledTaskIDs, [task.id])
    }

    func testBackfillTaskRemindersCancelsExistingRequestsAndSchedulesFutureActiveTasks() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let futureDue = Date(timeIntervalSince1970: 1_700_003_600)
        let futureStart = Date(timeIntervalSince1970: 1_700_007_200)
        let repository = InMemoryPlanningTaskRepository(tasks: [
            TaskItem(title: "未来截止", dueAt: futureDue, status: .todo, planLevel: .day, ownerUserId: "local"),
            TaskItem(title: "未来开始", startAt: futureStart, status: .postponed, planLevel: .day, ownerUserId: "local"),
            TaskItem(title: "已过期", dueAt: Date(timeIntervalSince1970: 1_699_999_000), status: .todo, planLevel: .day, ownerUserId: "local"),
            TaskItem(title: "已完成", dueAt: futureDue, status: .done, planLevel: .day, ownerUserId: "local"),
            TaskItem(title: "其他人任务", dueAt: futureDue, status: .todo, planLevel: .day, ownerUserId: "other")
        ])
        let notificationScheduler = TestNotificationScheduler()
        let notificationSettings = TestNotificationSettingsStore(isTaskRemindersEnabled: true)
        let service = DefaultPlanningTaskService(
            taskRepository: repository,
            ownerUserId: "local",
            notificationScheduler: notificationScheduler,
            notificationSettings: notificationSettings,
            nowProvider: { now }
        )
        let expectation = expectation(description: "backfill reminders")
        expectation.expectedFulfillmentCount = 3
        notificationScheduler.operationExpectation = expectation

        try service.backfillTaskReminders()
        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(notificationScheduler.didCancelAllTaskReminders)
        XCTAssertEqual(notificationScheduler.scheduledTaskReminders.map(\.title), ["未来截止", "未来开始"])
        XCTAssertEqual(notificationScheduler.scheduledTaskReminders.map(\.fireDate), [futureDue, futureStart])
        XCTAssertTrue(notificationScheduler.scheduledTaskReminders.allSatisfy { $0.kind == .personalTask })
    }

    func testBackfillTaskRemindersDoesNotScheduleWhenDisabledBeforeAsyncWorkContinues() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let futureDue = Date(timeIntervalSince1970: 1_700_003_600)
        let repository = InMemoryPlanningTaskRepository(tasks: [
            TaskItem(title: "未来截止", dueAt: futureDue, status: .todo, planLevel: .day, ownerUserId: "local")
        ])
        let notificationScheduler = TestNotificationScheduler()
        let notificationSettings = TestNotificationSettingsStore(isTaskRemindersEnabled: true)
        let service = DefaultPlanningTaskService(
            taskRepository: repository,
            ownerUserId: "local",
            notificationScheduler: notificationScheduler,
            notificationSettings: notificationSettings,
            nowProvider: { now }
        )
        let cancelAllStarted = expectation(description: "cancel all started")
        let completed = expectation(description: "backfill settled")
        let gate = AsyncGate()

        notificationScheduler.onCancelAllTaskReminders = {
            cancelAllStarted.fulfill()
            await gate.wait()
        }
        notificationScheduler.onScheduleTaskReminder = {
            XCTFail("should not schedule reminders after settings were disabled")
        }

        try service.backfillTaskReminders()
        wait(for: [cancelAllStarted], timeout: 1.0)
        notificationSettings.isTaskRemindersEnabled = false
        Task { await gate.open() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completed.fulfill()
        }
        wait(for: [completed], timeout: 1.0)

        XCTAssertTrue(notificationScheduler.didCancelAllTaskReminders)
        XCTAssertTrue(notificationScheduler.scheduledTaskReminders.isEmpty)
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

    func testCreateTaskSkipsCalendarSyncWhenDefaultCalendarIsMissing() throws {
        let repository = InMemoryPlanningTaskRepository(tasks: [])
        let calendarSync = TestCalendarSyncService()
        calendarSync.currentServiceAvailability = .failed("未找到可写入的系统日历。")
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
                detail: "",
                planLevel: .day,
                status: .todo,
                startAt: Date(timeIntervalSince1970: 1_700_000_000),
                dueAt: Date(timeIntervalSince1970: 1_700_003_600),
                isAllDay: false
            )
        )

        XCTAssertTrue(calendarSync.upsertedTaskTitles.isEmpty)
        XCTAssertNil(created.systemCalendarEventId)
        XCTAssertNil(repository.createdTasks.first?.systemCalendarEventId)
        XCTAssertTrue(repository.updatedTaskIDs.isEmpty)
    }

    func testUpdateTaskSyncsExistingCalendarEventWhenDefaultCalendarIsMissing() throws {
        let repository = InMemoryPlanningTaskRepository(tasks: [])
        let calendarSync = TestCalendarSyncService()
        calendarSync.currentServiceAvailability = .failed("未找到可写入的系统日历。")
        calendarSync.upsertedEventIdentifier = "event-123"
        let settings = TestCalendarSyncSettingsStore(isEnabled: true)
        let service = DefaultPlanningTaskService(
            taskRepository: repository,
            ownerUserId: "local",
            calendarSyncService: calendarSync,
            calendarSyncSettings: settings
        )
        let task = TaskItem(
            title: "产检预约",
            startAt: Date(timeIntervalSince1970: 1_700_000_000),
            dueAt: Date(timeIntervalSince1970: 1_700_003_600),
            status: .todo,
            planLevel: .day,
            ownerUserId: "local",
            systemCalendarEventId: "event-123"
        )

        try service.updateTask(
            task,
            from: PlanningTaskDraft(
                title: "产检预约（更新）",
                detail: "",
                planLevel: .day,
                status: .todo,
                startAt: Date(timeIntervalSince1970: 1_700_000_000),
                dueAt: Date(timeIntervalSince1970: 1_700_003_600),
                isAllDay: false
            )
        )

        XCTAssertEqual(calendarSync.upsertedTaskTitles, ["产检预约（更新）"])
        XCTAssertEqual(task.systemCalendarEventId, "event-123")
        XCTAssertEqual(repository.updatedTaskIDs, [task.id])
    }

    func testCreateTaskDoesNotTouchCalendarWhenRepositoryCreateFails() {
        let repository = InMemoryPlanningTaskRepository(tasks: [])
        repository.createError = TestRepositoryError.failed
        let calendarSync = TestCalendarSyncService()
        let settings = TestCalendarSyncSettingsStore(isEnabled: true)
        let service = DefaultPlanningTaskService(
            taskRepository: repository,
            ownerUserId: "local",
            calendarSyncService: calendarSync,
            calendarSyncSettings: settings
        )

        XCTAssertThrowsError(
            try service.createTask(
                from: PlanningTaskDraft(
                    title: "产检预约",
                    detail: "",
                    planLevel: .day,
                    status: .todo,
                    startAt: Date(timeIntervalSince1970: 1_700_000_000),
                    dueAt: nil,
                    isAllDay: false
                )
            )
        )
        XCTAssertTrue(calendarSync.upsertedTaskTitles.isEmpty)
    }

    func testUpdateTaskDoesNotTouchCalendarWhenRepositoryUpdateFails() {
        let repository = InMemoryPlanningTaskRepository(tasks: [])
        repository.updateError = TestRepositoryError.failed
        let calendarSync = TestCalendarSyncService()
        let settings = TestCalendarSyncSettingsStore(isEnabled: true)
        let service = DefaultPlanningTaskService(
            taskRepository: repository,
            ownerUserId: "local",
            calendarSyncService: calendarSync,
            calendarSyncSettings: settings
        )
        let task = TaskItem(title: "产检预约", status: .todo, planLevel: .day, ownerUserId: "local")

        XCTAssertThrowsError(
            try service.updateTask(
                task,
                from: PlanningTaskDraft(
                    title: "产检预约（更新）",
                    detail: "",
                    planLevel: .day,
                    status: .todo,
                    startAt: Date(timeIntervalSince1970: 1_700_000_000),
                    dueAt: nil,
                    isAllDay: false
                )
            )
        )
        XCTAssertTrue(calendarSync.upsertedTaskTitles.isEmpty)
    }

    func testDeleteTaskDeletesLinkedCalendarEventAfterRemovingTask() throws {
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
        XCTAssertEqual(calendarSync.operationLog, [.deleteTask(task.id), .deleteEvent("event-123")])
    }

    func testDeleteTaskDoesNotTouchCalendarWhenSyncIsDisabled() throws {
        let repository = InMemoryPlanningTaskRepository(tasks: [])
        let calendarSync = TestCalendarSyncService()
        let settings = TestCalendarSyncSettingsStore(isEnabled: false)
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

        XCTAssertTrue(calendarSync.deletedEventIdentifiers.isEmpty)
        XCTAssertEqual(repository.deletedTaskIDs, [task.id])
        XCTAssertEqual(calendarSync.operationLog, [.deleteTask(task.id)])
    }

    func testDeleteTaskDoesNotTouchCalendarWhenRepositoryDeleteFails() {
        let repository = InMemoryPlanningTaskRepository(tasks: [])
        repository.deleteError = TestRepositoryError.failed
        let calendarSync = TestCalendarSyncService()
        let settings = TestCalendarSyncSettingsStore(isEnabled: true)
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

        XCTAssertThrowsError(try service.deleteTask(task))
        XCTAssertTrue(calendarSync.deletedEventIdentifiers.isEmpty)
    }

    func testUnscheduleKeepsEventIdentifierWhenCalendarDeleteFails() throws {
        let repository = InMemoryPlanningTaskRepository(tasks: [])
        let calendarSync = TestCalendarSyncService()
        calendarSync.deleteError = CalendarSyncError.operationFailed("remove failed")
        let settings = TestCalendarSyncSettingsStore(isEnabled: true)
        let service = DefaultPlanningTaskService(
            taskRepository: repository,
            ownerUserId: "local",
            calendarSyncService: calendarSync,
            calendarSyncSettings: settings
        )
        let task = TaskItem(
            title: "产检预约",
            startAt: Date(timeIntervalSince1970: 1_700_000_000),
            dueAt: nil,
            status: .todo,
            planLevel: .day,
            ownerUserId: "local",
            systemCalendarEventId: "event-123"
        )

        try service.updateTask(
            task,
            from: PlanningTaskDraft(
                title: "产检预约",
                detail: "",
                planLevel: .day,
                status: .todo,
                startAt: nil,
                dueAt: nil,
                isAllDay: false
            )
        )

        XCTAssertEqual(calendarSync.deletedEventIdentifiers, ["event-123"])
        XCTAssertEqual(task.systemCalendarEventId, "event-123")
        XCTAssertEqual(repository.updatedTaskIDs, [task.id])
    }
}

private final class InMemoryPlanningTaskRepository: TaskRepository {
    private var items: [TaskItem]
    private(set) var updatedTaskIDs: [UUID] = []
    private(set) var createdTasks: [TaskItem] = []
    private(set) var deletedTaskIDs: [UUID] = []
    var onDelete: ((TaskItem) -> Void)?
    var createError: Error?
    var updateError: Error?
    var deleteError: Error?

    init(tasks: [TaskItem]) {
        self.items = tasks
    }

    func create(_ task: TaskItem) throws {
        if let createError {
            throw createError
        }
        items.append(task)
        createdTasks.append(task)
    }

    func update(_ task: TaskItem) throws {
        if let updateError {
            throw updateError
        }
        updatedTaskIDs.append(task.id)
    }

    func delete(_ task: TaskItem) throws {
        if let deleteError {
            throw deleteError
        }
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

private enum TestRepositoryError: Error {
    case failed
}
