import Foundation

@MainActor
final class PlanningViewModel: ObservableObject {
    enum CalendarSyncBannerStyle: Equatable {
        case neutral
        case success
        case warning
    }

    enum DisplayMode: String, CaseIterable, Identifiable {
        case plan = "计划视图"
        case list = "列表视图"

        var id: Self { self }
    }

    enum StatusFilter: String, CaseIterable, Identifiable {
        case active
        case all
        case todo
        case postponed
        case done
        case cancelled

        var id: Self { self }

        var title: String {
            switch self {
            case .active:
                return "待处理"
            case .all:
                return "全部"
            case .todo:
                return "待办"
            case .postponed:
                return "已延期"
            case .done:
                return "已完成"
            case .cancelled:
                return "已取消"
            }
        }
    }

    enum DateRangeFilter: String, CaseIterable, Identifiable {
        case all = "全部"
        case today = "今天"
        case next7Days = "近 7 天"
        case next30Days = "近 30 天"
        case custom = "自定义"

        var id: Self { self }
    }

    struct StatusSection: Identifiable {
        let status: TaskStatus
        let tasks: [TaskItem]

        var id: String { status.rawValue }
    }

    struct PlanSection: Identifiable {
        let date: Date?
        let title: String
        let tasks: [TaskItem]

        var id: String {
            if let date {
                return "date-\(date.timeIntervalSince1970)"
            }
            return "unplanned"
        }
    }

    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadErrorMessage: String?
    @Published var displayMode: DisplayMode = .list
    @Published var selectedPlanLevel: PlanLevel = .day
    @Published var selectedStatusFilter: StatusFilter = .active
    @Published var dateRangeFilter: DateRangeFilter = .all
    @Published var customDateRangeStart: Date
    @Published var customDateRangeEnd: Date
    @Published var editor: PlanningTaskEditor?
    @Published private(set) var calendarSyncStatus = CalendarSyncStatus(isEnabled: false, availability: .notAuthorized)
    @Published private(set) var notificationSettingsStatus = NotificationSettingsStatus(
        isTaskRemindersEnabled: false,
        isWaterReminderEnabled: false,
        availability: .notAuthorized
    )
    @Published private(set) var isUpdatingCalendarSync = false
    @Published private(set) var isUpdatingNotificationSettings = false

    private let service: any PlanningTaskService
    private let calendarSyncController: any CalendarSyncSettingsControlling
    private let notificationController: any NotificationSettingsControlling
    private let calendar: Calendar
    private let nowProvider: () -> Date

    init(
        service: any PlanningTaskService,
        calendarSyncController: any CalendarSyncSettingsControlling,
        notificationController: any NotificationSettingsControlling = DefaultNotificationSettingsController(
            notificationScheduler: NoopNotificationScheduler(),
            settingsStore: UserDefaultsNotificationSettingsStore()
        ),
        calendar: Calendar = .current,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.service = service
        self.calendarSyncController = calendarSyncController
        self.notificationController = notificationController
        self.calendar = calendar
        self.nowProvider = nowProvider

        let today = calendar.startOfDay(for: nowProvider())
        _customDateRangeStart = Published(initialValue: today)
        _customDateRangeEnd = Published(initialValue: today)
    }

    var sections: [StatusSection] {
        statusSections
    }

    var statusSections: [StatusSection] {
        let visibleTasks = filteredTasks
        let groupedTasks = Dictionary(grouping: visibleTasks, by: \.status)
        return visibleStatuses.compactMap { status in
            guard let tasks = groupedTasks[status], !tasks.isEmpty else {
                return nil
            }
            return StatusSection(status: status, tasks: tasks)
        }
    }

    var planSections: [PlanSection] {
        let visibleTasks = filteredTasks
        let scheduledTasks = visibleTasks.compactMap { task -> (date: Date, task: TaskItem)? in
            guard let scheduledAt = task.scheduledAt else { return nil }
            return (date: groupingStartDate(for: scheduledAt), task: task)
        }

        let groupedTasks = Dictionary(grouping: scheduledTasks, by: \.date)
        let scheduledSections = groupedTasks.keys.sorted().map { date in
            let tasks = groupedTasks[date]?.map(\.task) ?? []
            return PlanSection(date: date, title: formatSectionDate(date), tasks: tasks)
        }

        guard dateRangeFilter == .all else {
            return scheduledSections
        }

        let unscheduledTasks = visibleTasks.filter { $0.scheduledAt == nil }
        guard !unscheduledTasks.isEmpty else {
            return scheduledSections
        }

        return scheduledSections + [
            PlanSection(date: nil, title: "未排期", tasks: unscheduledTasks)
        ]
    }

    var listSubtitle: String {
        summarySubtitle(levelLabel: "\(selectedPlanLevel.title)计划")
    }

    var planSubtitle: String {
        summarySubtitle(levelLabel: "\(selectedPlanLevel.title)计划")
    }

    var emptyStateTitle: String {
        if tasks.isEmpty {
            return "还没有任务"
        }
        return "当前筛选下没有任务"
    }

    var emptyStateMessage: String {
        if tasks.isEmpty {
            return "先添加一条任务，开始安排日/周/月/年计划。"
        }
        return "可切换层级、状态或日期范围筛选，或新建一条任务。"
    }

    var isCalendarSyncEnabled: Bool {
        calendarSyncStatus.isEnabled
    }

    var isTaskRemindersEnabled: Bool {
        notificationSettingsStatus.isTaskRemindersEnabled
    }

    var isWaterReminderEnabled: Bool {
        notificationSettingsStatus.isWaterReminderEnabled
    }

    var calendarSyncSummary: String {
        switch (calendarSyncStatus.isEnabled, calendarSyncStatus.availability) {
        case (true, .available):
            return "已同步到系统日历。新建、更新、删除任务会尝试写入默认日历。"
        case (false, .available):
            return "已获得系统日历权限。开启后才会把任务写入默认日历。"
        case (_, .notAuthorized):
            return "未授权时不会写入系统日历；开启时会按需申请权限。"
        case (_, .notSupported):
            return "当前环境不支持系统日历同步。模拟器和真机的权限表现可能不同。"
        case (_, .failed(let message)):
            return message
        }
    }

    var notificationSummary: String {
        switch notificationSettingsStatus.availability {
        case .available:
            switch (notificationSettingsStatus.isTaskRemindersEnabled, notificationSettingsStatus.isWaterReminderEnabled) {
            case (true, true):
                return "任务提醒已开启；喝水提醒会在每天 10:00 发送。"
            case (true, false):
                return "任务提醒已开启；喝水提醒仍保持关闭。"
            case (false, true):
                return "喝水提醒会在每天 10:00 发送；任务提醒仍保持关闭。"
            case (false, false):
                return "通知权限已可用。你可以分别开启任务提醒和喝水提醒。"
            }
        case .notAuthorized:
            return "未授权时不会发送任何本地通知。你可以在这里尝试开启，或前往“我的”页检查通知权限。"
        case .notSupported:
            return "当前环境不支持本地通知提醒；两个开关都会保持关闭。"
        case .failed(let message):
            return message
        }
    }

    var calendarSyncBannerStyle: CalendarSyncBannerStyle {
        switch (calendarSyncStatus.isEnabled, calendarSyncStatus.availability) {
        case (true, .available):
            return .success
        case (_, .failed), (_, .notAuthorized), (_, .notSupported):
            return .warning
        default:
            return .neutral
        }
    }

    func load() {
        isLoading = true
        defer { isLoading = false }

        do {
            tasks = try service.loadTasks()
            loadErrorMessage = nil
        } catch {
            tasks = []
            loadErrorMessage = "任务列表加载失败，请稍后重试。"
        }
    }

    func loadCalendarSyncStatus() async {
        calendarSyncStatus = await calendarSyncController.currentStatus()
    }

    func loadNotificationSettingsStatus() async {
        notificationSettingsStatus = await notificationController.currentStatus()
    }

    func setCalendarSyncEnabled(_ enabled: Bool) async {
        isUpdatingCalendarSync = true
        defer { isUpdatingCalendarSync = false }
        calendarSyncStatus = await calendarSyncController.setSyncEnabled(enabled)
    }

    func setTaskRemindersEnabled(_ enabled: Bool) async {
        isUpdatingNotificationSettings = true
        defer { isUpdatingNotificationSettings = false }
        notificationSettingsStatus = await notificationController.setTaskRemindersEnabled(enabled)
    }

    func setWaterReminderEnabled(_ enabled: Bool) async {
        isUpdatingNotificationSettings = true
        defer { isUpdatingNotificationSettings = false }
        notificationSettingsStatus = await notificationController.setWaterReminderEnabled(enabled)
    }

    func startAdd() {
        editor = PlanningTaskEditor(
            title: "新增任务",
            saveButtonTitle: "保存",
            task: nil,
            draft: service.makeDraft(for: nil)
        )
    }

    func startEdit(_ task: TaskItem) {
        editor = PlanningTaskEditor(
            title: "编辑任务",
            saveButtonTitle: "更新",
            task: task,
            draft: service.makeDraft(for: task)
        )
    }

    func cancelEditing() {
        editor = nil
    }

    func save(draft: PlanningTaskDraft) -> String? {
        guard let editor else {
            return "当前没有可保存的任务。"
        }

        do {
            if let task = editor.task {
                try service.updateTask(task, from: draft)
            } else {
                _ = try service.createTask(from: draft)
            }
            self.editor = nil
            load()
            return nil
        } catch let validationError as PlanningTaskValidationError {
            return validationError.errorDescription ?? "任务校验失败。"
        } catch {
            loadErrorMessage = "保存任务失败，请稍后重试。"
            return loadErrorMessage
        }
    }

    func markDone(_ task: TaskItem) {
        do {
            try service.markTaskDone(task)
            load()
        } catch let validationError as PlanningTaskValidationError {
            loadErrorMessage = validationError.errorDescription ?? "更新任务状态失败，请稍后重试。"
        } catch {
            loadErrorMessage = "更新任务状态失败，请稍后重试。"
        }
    }

    func postpone(_ task: TaskItem) {
        do {
            try service.postponeTask(task)
            load()
        } catch let validationError as PlanningTaskValidationError {
            loadErrorMessage = validationError.errorDescription ?? "延期任务失败，请稍后重试。"
        } catch {
            loadErrorMessage = "延期任务失败，请稍后重试。"
        }
    }

    func cancel(_ task: TaskItem) {
        do {
            try service.cancelTask(task)
            load()
        } catch let validationError as PlanningTaskValidationError {
            loadErrorMessage = validationError.errorDescription ?? "取消任务失败，请稍后重试。"
        } catch {
            loadErrorMessage = "取消任务失败，请稍后重试。"
        }
    }

    func delete(_ task: TaskItem) {
        do {
            try service.deleteTask(task)
            load()
        } catch {
            loadErrorMessage = "删除任务失败，请稍后重试。"
        }
    }

    private var filteredTasks: [TaskItem] {
        let interval = dateRangeInterval
        return tasks.filter { task in
            guard task.planLevel == selectedPlanLevel else {
                return false
            }

            guard matchesStatus(task.status) else {
                return false
            }

            return matchesDateRange(task, interval: interval)
        }
    }

    private var visibleStatuses: [TaskStatus] {
        switch selectedStatusFilter {
        case .active:
            return [.todo, .postponed]
        case .all:
            return [.todo, .postponed, .done, .cancelled]
        case .todo:
            return [.todo]
        case .postponed:
            return [.postponed]
        case .done:
            return [.done]
        case .cancelled:
            return [.cancelled]
        }
    }

    private var dateRangeInterval: DateInterval? {
        switch dateRangeFilter {
        case .all:
            return nil
        case .today:
            let start = calendar.startOfDay(for: nowProvider())
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
                return nil
            }
            return DateInterval(start: start, end: end)
        case .next7Days:
            return relativeInterval(days: 7)
        case .next30Days:
            return relativeInterval(days: 30)
        case .custom:
            let start = calendar.startOfDay(for: customDateRangeStart)
            let end = calendar.startOfDay(for: customDateRangeEnd)
            let lowerBound = min(start, end)
            let upperBound = calendar.date(byAdding: .day, value: 1, to: max(start, end)) ?? max(start, end)
            return DateInterval(start: lowerBound, end: upperBound)
        }
    }

    private func relativeInterval(days: Int) -> DateInterval? {
        let start = calendar.startOfDay(for: nowProvider())
        guard let end = calendar.date(byAdding: .day, value: days, to: start) else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }

    private func matchesStatus(_ status: TaskStatus) -> Bool {
        switch selectedStatusFilter {
        case .active:
            return status == .todo || status == .postponed
        case .all:
            return true
        case .todo:
            return status == .todo
        case .postponed:
            return status == .postponed
        case .done:
            return status == .done
        case .cancelled:
            return status == .cancelled
        }
    }

    private func matchesDateRange(_ task: TaskItem, interval: DateInterval?) -> Bool {
        guard let interval else {
            return true
        }
        guard let scheduledAt = task.scheduledAt else {
            return false
        }
        return interval.contains(scheduledAt)
    }

    private func summarySubtitle(levelLabel: String) -> String {
        let visibleTasks = filteredTasks
        let filterLabel = "层级 \(levelLabel) · 状态 \(selectedStatusFilter.title) · 日期 \(dateRangeFilter.title)"
        if visibleTasks.isEmpty {
            return "\(filterLabel) 暂无任务"
        }
        return "\(filterLabel) · 共 \(visibleTasks.count) 条"
    }

    private func formatSectionDate(_ date: Date) -> String {
        switch selectedPlanLevel {
        case .day:
            return format(date, dateFormat: "yyyy-MM-dd")
        case .week:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
                return format(date, dateFormat: "yyyy-MM-dd")
            }
            let start = calendar.startOfDay(for: interval.start)
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            return "\(format(start, dateFormat: "yyyy-MM-dd")) ~ \(format(end, dateFormat: "yyyy-MM-dd"))"
        case .month:
            return format(date, dateFormat: "yyyy年M月")
        case .year:
            return format(date, dateFormat: "yyyy年")
        }
    }

    private func groupingStartDate(for date: Date) -> Date {
        switch selectedPlanLevel {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
                return calendar.startOfDay(for: date)
            }
            return calendar.startOfDay(for: interval.start)
        case .month:
            guard let interval = calendar.dateInterval(of: .month, for: date) else {
                return calendar.startOfDay(for: date)
            }
            return calendar.startOfDay(for: interval.start)
        case .year:
            guard let interval = calendar.dateInterval(of: .year, for: date) else {
                return calendar.startOfDay(for: date)
            }
            return calendar.startOfDay(for: interval.start)
        }
    }

    private func format(_ date: Date, dateFormat: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .autoupdatingCurrent
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }
}

struct PlanningTaskEditor: Identifiable {
    let id = UUID()
    let title: String
    let saveButtonTitle: String
    let task: TaskItem?
    let draft: PlanningTaskDraft
}
