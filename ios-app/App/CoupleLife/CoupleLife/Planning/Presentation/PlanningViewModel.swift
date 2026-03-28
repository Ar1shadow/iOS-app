import Foundation

@MainActor
final class PlanningViewModel: ObservableObject {
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

    struct Section: Identifiable {
        let status: TaskStatus
        let tasks: [TaskItem]

        var id: String { status.rawValue }
    }

    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadErrorMessage: String?
    @Published var selectedPlanLevel: PlanLevel = .day
    @Published var selectedStatusFilter: StatusFilter = .active
    @Published var editor: PlanningTaskEditor?

    private let service: any PlanningTaskService

    init(service: any PlanningTaskService) {
        self.service = service
    }

    var sections: [Section] {
        let groupedTasks = Dictionary(grouping: filteredTasks, by: \.status)
        return visibleStatuses.compactMap { status in
            guard let tasks = groupedTasks[status], !tasks.isEmpty else {
                return nil
            }
            return Section(status: status, tasks: tasks)
        }
    }

    var listSubtitle: String {
        let levelTitle = selectedPlanLevel.title
        if filteredTasks.isEmpty {
            return "\(levelTitle)计划暂无任务"
        }
        return "\(levelTitle)计划 · 共 \(filteredTasks.count) 条"
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
        return "可切换层级或状态筛选，或新建一条任务。"
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
        } catch {
            loadErrorMessage = "更新任务状态失败，请稍后重试。"
        }
    }

    func postpone(_ task: TaskItem) {
        do {
            try service.postponeTask(task)
            load()
        } catch {
            loadErrorMessage = "延期任务失败，请稍后重试。"
        }
    }

    func cancel(_ task: TaskItem) {
        do {
            try service.cancelTask(task)
            load()
        } catch {
            loadErrorMessage = "取消任务失败，请稍后重试。"
        }
    }

    private var filteredTasks: [TaskItem] {
        tasks
            .filter { $0.planLevel == selectedPlanLevel }
            .filter { task in
                switch selectedStatusFilter {
                case .active:
                    return task.status == .todo || task.status == .postponed
                case .all:
                    return true
                case .todo:
                    return task.status == .todo
                case .postponed:
                    return task.status == .postponed
                case .done:
                    return task.status == .done
                case .cancelled:
                    return task.status == .cancelled
                }
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
}

struct PlanningTaskEditor: Identifiable {
    let id = UUID()
    let title: String
    let saveButtonTitle: String
    let task: TaskItem?
    let draft: PlanningTaskDraft
}
