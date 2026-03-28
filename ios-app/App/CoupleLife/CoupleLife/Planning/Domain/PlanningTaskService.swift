import Foundation

struct PlanningTaskDraft: Equatable {
    var title: String
    var detail: String
    var planLevel: PlanLevel
    var status: TaskStatus
    var startAt: Date?
    var dueAt: Date?
    var isAllDay: Bool
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
}

final class DefaultPlanningTaskService: PlanningTaskService {
    private let taskRepository: any TaskRepository
    private let ownerUserId: String
    private let calendar: Calendar
    private let calendarSyncService: any CalendarSyncService
    private let calendarSyncSettings: any CalendarSyncSettingsStore
    private let nowProvider: () -> Date

    init(
        taskRepository: any TaskRepository,
        ownerUserId: String,
        calendar: Calendar = .current,
        calendarSyncService: any CalendarSyncService = NoopCalendarSyncService(),
        calendarSyncSettings: any CalendarSyncSettingsStore = UserDefaultsCalendarSyncSettingsStore(),
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.taskRepository = taskRepository
        self.ownerUserId = ownerUserId
        self.calendar = calendar
        self.calendarSyncService = calendarSyncService
        self.calendarSyncSettings = calendarSyncSettings
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
                isAllDay: false
            )
        }

        return PlanningTaskDraft(
            title: task.title,
            detail: task.detail ?? "",
            planLevel: task.planLevel,
            status: task.status,
            startAt: task.startAt,
            dueAt: task.dueAt,
            isAllDay: task.isAllDay
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
            createdAt: now,
            updatedAt: now
        )
        syncTaskToCalendarIfNeeded(task)
        try taskRepository.create(task)
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
        syncTaskToCalendarIfNeeded(task)
        try taskRepository.update(task)
    }

    func markTaskDone(_ task: TaskItem) throws {
        try ensureMutableStatus(task.status)
        task.status = .done
        syncTaskToCalendarIfNeeded(task)
        try taskRepository.update(task)
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
        syncTaskToCalendarIfNeeded(task)
        try taskRepository.update(task)
    }

    func cancelTask(_ task: TaskItem) throws {
        try ensureMutableStatus(task.status)
        task.status = .cancelled
        syncTaskToCalendarIfNeeded(task)
        try taskRepository.update(task)
    }

    func deleteTask(_ task: TaskItem) throws {
        deleteLinkedCalendarEventIfNeeded(for: task)
        try taskRepository.delete(task)
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
            isAllDay: draft.isAllDay
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

    private func syncTaskToCalendarIfNeeded(_ task: TaskItem) {
        guard calendarSyncSettings.isEnabled else { return }

        if task.startAt == nil && task.dueAt == nil {
            deleteLinkedCalendarEventIfNeeded(for: task)
            task.systemCalendarEventId = nil
            return
        }

        guard calendarSyncService.currentAvailability() == .available else { return }

        do {
            task.systemCalendarEventId = try calendarSyncService.upsertEvent(for: task)
        } catch {
            // Calendar sync is best-effort in MVP; task CRUD should keep working when EventKit fails.
        }
    }

    private func deleteLinkedCalendarEventIfNeeded(for task: TaskItem) {
        guard calendarSyncSettings.isEnabled else { return }
        guard let eventIdentifier = task.systemCalendarEventId else { return }

        do {
            try calendarSyncService.deleteEvent(withIdentifier: eventIdentifier)
        } catch {
            // Deleting the task should not be blocked by a missing permission or stale event identifier.
        }
    }
}
