import Foundation

struct PlanningTaskDraft: Equatable {
    var title: String
    var detail: String
    var planLevel: PlanLevel
    var status: TaskStatus
    var startAt: Date?
    var dueAt: Date?
    var isAllDay: Bool
    var visibility: Visibility = .private
}

enum PlanningTaskValidationError: LocalizedError, Equatable {
    case emptyTitle
    case invalidStatusTransition

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "请填写任务标题。"
        case .invalidStatusTransition:
            return "当前任务状态不允许这样变更。"
        }
    }
}

protocol PlanningTaskService {
    func loadTasks() throws -> [TaskItem]
    func makeDraft(for task: TaskItem?) -> PlanningTaskDraft
    @discardableResult func createTask(from draft: PlanningTaskDraft) throws -> TaskItem
    func updateTask(_ task: TaskItem, from draft: PlanningTaskDraft) throws
    func markTaskDone(_ task: TaskItem) throws
    func postponeTask(_ task: TaskItem) throws
    func cancelTask(_ task: TaskItem) throws
    func deleteTask(_ task: TaskItem) throws
    func backfillTaskReminders() throws
}

final class DefaultPlanningTaskService: PlanningTaskService {
    private let taskRepository: any TaskRepository
    private let ownerUserId: String
    private let calendar: Calendar
    private let calendarSyncService: any CalendarSyncService
    private let calendarSyncSettings: any CalendarSyncSettingsStore
    private let notificationScheduler: any NotificationScheduler
    private let notificationSettings: any NotificationSettingsStore
    private let nowProvider: () -> Date

    init(
        taskRepository: any TaskRepository,
        ownerUserId: String,
        calendar: Calendar = .current,
        calendarSyncService: any CalendarSyncService = NoopCalendarSyncService(),
        calendarSyncSettings: any CalendarSyncSettingsStore = UserDefaultsCalendarSyncSettingsStore(),
        notificationScheduler: any NotificationScheduler = NoopNotificationScheduler(),
        notificationSettings: any NotificationSettingsStore = UserDefaultsNotificationSettingsStore(),
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.taskRepository = taskRepository
        self.ownerUserId = ownerUserId
        self.calendar = calendar
        self.calendarSyncService = calendarSyncService
        self.calendarSyncSettings = calendarSyncSettings
        self.notificationScheduler = notificationScheduler
        self.notificationSettings = notificationSettings
        self.nowProvider = nowProvider
    }

    func loadTasks() throws -> [TaskItem] {
        try taskRepository.tasks(status: nil)
            .filter { $0.ownerUserId == ownerUserId }
            .sorted(by: sortTasks)
    }

    func makeDraft(for task: TaskItem?) -> PlanningTaskDraft {
        guard let task else {
            return PlanningTaskDraft(
                title: "",
                detail: "",
                planLevel: .day,
                status: .todo,
                startAt: nil,
                dueAt: nil,
                isAllDay: false,
                visibility: .private
            )
        }

        return PlanningTaskDraft(
            title: task.title,
            detail: task.detail ?? "",
            planLevel: task.planLevel,
            status: task.status,
            startAt: task.startAt,
            dueAt: task.dueAt,
            isAllDay: task.isAllDay,
            visibility: task.visibility
        )
    }

    @discardableResult
    func createTask(from draft: PlanningTaskDraft) throws -> TaskItem {
        let normalizedDraft = try validate(draft)
        let now = nowProvider()
        let task = TaskItem(
            title: normalizedDraft.title,
            detail: normalizedDraft.detail.isEmpty ? nil : normalizedDraft.detail,
            startAt: normalizedDraft.startAt,
            dueAt: normalizedDraft.dueAt,
            isAllDay: normalizedDraft.isAllDay,
            status: .todo,
            planLevel: normalizedDraft.planLevel,
            ownerUserId: ownerUserId,
            visibility: normalizedDraft.visibility,
            createdAt: now,
            updatedAt: now
        )
        try taskRepository.create(task)
        performPostPersistenceCalendarSync(for: task, persistedEventIdentifier: nil)
        performPostPersistenceNotificationSync(for: task)
        return task
    }

    func updateTask(_ task: TaskItem, from draft: PlanningTaskDraft) throws {
        let normalizedDraft = try validate(draft)
        guard normalizedDraft.status == task.status else {
            throw PlanningTaskValidationError.invalidStatusTransition
        }
        task.title = normalizedDraft.title
        task.detail = normalizedDraft.detail.isEmpty ? nil : normalizedDraft.detail
        task.planLevel = normalizedDraft.planLevel
        task.startAt = normalizedDraft.startAt
        task.dueAt = normalizedDraft.dueAt
        task.isAllDay = normalizedDraft.isAllDay
        task.visibility = normalizedDraft.visibility
        try taskRepository.update(task)
        performPostPersistenceCalendarSync(for: task, persistedEventIdentifier: task.systemCalendarEventId)
        performPostPersistenceNotificationSync(for: task)
    }

    func markTaskDone(_ task: TaskItem) throws {
        try ensureMutableStatus(task.status)
        task.status = .done
        try taskRepository.update(task)
        performPostPersistenceCalendarSync(for: task, persistedEventIdentifier: task.systemCalendarEventId)
        performPostPersistenceNotificationSync(for: task)
    }

    func postponeTask(_ task: TaskItem) throws {
        try ensureMutableStatus(task.status)
        if let startAt = task.startAt {
            task.startAt = calendar.date(byAdding: .day, value: 1, to: startAt)
        }
        if let dueAt = task.dueAt {
            task.dueAt = calendar.date(byAdding: .day, value: 1, to: dueAt)
        }
        task.status = .postponed
        try taskRepository.update(task)
        performPostPersistenceCalendarSync(for: task, persistedEventIdentifier: task.systemCalendarEventId)
        performPostPersistenceNotificationSync(for: task)
    }

    func cancelTask(_ task: TaskItem) throws {
        try ensureMutableStatus(task.status)
        task.status = .cancelled
        try taskRepository.update(task)
        performPostPersistenceCalendarSync(for: task, persistedEventIdentifier: task.systemCalendarEventId)
        performPostPersistenceNotificationSync(for: task)
    }

    func deleteTask(_ task: TaskItem) throws {
        let eventIdentifier = task.systemCalendarEventId
        let taskID = task.id
        try taskRepository.delete(task)
        _ = deleteLinkedCalendarEventIfNeeded(eventIdentifier)
        cancelLinkedNotificationReminderIfNeeded(taskID: taskID)
    }

    func backfillTaskReminders() throws {
        let now = nowProvider()
        let tasks = try loadTasks()
            .filter { $0.status == .todo || $0.status == .postponed }
            .compactMap { task -> TaskReminderPayload? in
                guard let fireDate = task.dueAt ?? task.startAt, fireDate > now else { return nil }
                return TaskReminderPayload(
                    id: task.id,
                    title: task.title,
                    fireDate: fireDate,
                    kind: .personalTask
                )
            }

        Task {
            guard notificationSettings.isTaskRemindersEnabled else { return }
            await notificationScheduler.cancelAllTaskReminders()
            for reminder in tasks {
                guard notificationSettings.isTaskRemindersEnabled else { return }
                await notificationScheduler.scheduleTaskReminder(reminder)
            }
        }
    }

    private func validate(_ draft: PlanningTaskDraft) throws -> PlanningTaskDraft {
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw PlanningTaskValidationError.emptyTitle
        }

        let trimmedDetail = draft.detail.trimmingCharacters(in: .whitespacesAndNewlines)

        return PlanningTaskDraft(
            title: trimmedTitle,
            detail: trimmedDetail,
            planLevel: draft.planLevel,
            status: draft.status,
            startAt: draft.startAt,
            dueAt: draft.dueAt,
            isAllDay: draft.isAllDay,
            visibility: VisibilityPolicy.task.sanitized(draft.visibility)
        )
    }

    private func sortTasks(lhs: TaskItem, rhs: TaskItem) -> Bool {
        let lhsScheduledAt = lhs.dueAt ?? lhs.startAt
        let rhsScheduledAt = rhs.dueAt ?? rhs.startAt

        switch (lhsScheduledAt, rhsScheduledAt) {
        case let (lhsDate?, rhsDate?):
            if lhsDate == rhsDate {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhsDate < rhsDate
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        case (nil, nil):
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private func ensureMutableStatus(_ status: TaskStatus) throws {
        guard status == .todo || status == .postponed else {
            throw PlanningTaskValidationError.invalidStatusTransition
        }
    }

    private func performPostPersistenceCalendarSync(for task: TaskItem, persistedEventIdentifier: String?) {
        guard calendarSyncSettings.isEnabled else { return }

        if task.startAt == nil && task.dueAt == nil {
            guard persistedEventIdentifier != nil else { return }
            guard deleteLinkedCalendarEventIfNeeded(persistedEventIdentifier) else { return }
            persistCalendarEventIdentifier(nil, for: task, previousIdentifier: persistedEventIdentifier)
            return
        }

        if persistedEventIdentifier == nil && calendarSyncService.currentAvailability() != .available {
            return
        }

        do {
            let eventIdentifier = try calendarSyncService.upsertEvent(for: task)
            guard eventIdentifier != persistedEventIdentifier else { return }
            persistCalendarEventIdentifier(eventIdentifier, for: task, previousIdentifier: persistedEventIdentifier)
        } catch {
            // Calendar sync is best-effort in MVP; task CRUD should keep working when EventKit fails.
        }
    }

    private func deleteLinkedCalendarEventIfNeeded(_ eventIdentifier: String?) -> Bool {
        guard calendarSyncSettings.isEnabled else { return false }
        guard let eventIdentifier else { return true }

        do {
            try calendarSyncService.deleteEvent(withIdentifier: eventIdentifier)
            return true
        } catch {
            // Calendar cleanup is best-effort; keep the persisted identifier when removal fails.
            return false
        }
    }

    private func persistCalendarEventIdentifier(
        _ eventIdentifier: String?,
        for task: TaskItem,
        previousIdentifier: String?
    ) {
        task.systemCalendarEventId = eventIdentifier

        do {
            try taskRepository.update(task)
        } catch {
            task.systemCalendarEventId = previousIdentifier
        }
    }

    private func performPostPersistenceNotificationSync(for task: TaskItem) {
        guard task.status == .todo || task.status == .postponed else {
            cancelLinkedNotificationReminderIfNeeded(taskID: task.id)
            return
        }

        guard let fireDate = task.dueAt ?? task.startAt else {
            cancelLinkedNotificationReminderIfNeeded(taskID: task.id)
            return
        }

        let reminder = TaskReminderPayload(
            id: task.id,
            title: task.title,
            fireDate: fireDate,
            kind: .personalTask
        )

        Task {
            guard notificationSettings.isTaskRemindersEnabled else { return }
            await notificationScheduler.scheduleTaskReminder(reminder)
        }
    }

    private func cancelLinkedNotificationReminderIfNeeded(taskID: UUID) {
        Task {
            guard notificationSettings.isTaskRemindersEnabled else { return }
            await notificationScheduler.cancelTaskReminder(id: taskID)
        }
    }
}
