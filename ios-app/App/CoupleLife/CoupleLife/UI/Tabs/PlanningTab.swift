import SwiftUI

struct PlanningTab: View {
    @StateObject private var viewModel: PlanningViewModel
    private let calendar: Calendar

    init(
        taskRepository: any TaskRepository,
        calendar: Calendar = .current,
        ownerUserId: String = CurrentUser.id,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.calendar = calendar
        let service = DefaultPlanningTaskService(
            taskRepository: taskRepository,
            ownerUserId: ownerUserId,
            calendar: calendar,
            nowProvider: nowProvider
        )
        _viewModel = StateObject(
            wrappedValue: PlanningViewModel(
                service: service,
                calendar: calendar,
                nowProvider: nowProvider
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    filterSection

                    if let loadErrorMessage = viewModel.loadErrorMessage {
                        SharedEmptyStateView(
                            title: "计划暂不可用",
                            message: loadErrorMessage,
                            symbolName: "exclamationmark.triangle"
                        )
                    }

                    taskContentSection
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.lg)
            }
            .background(AppColorToken.background.color.ignoresSafeArea())
            .navigationTitle("计划")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.startAdd()
                    } label: {
                        Label("新增任务", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(item: $viewModel.editor) { editor in
            PlanningTaskFormView(
                editor: editor,
                onSave: { draft in
                    viewModel.save(draft: draft)
                },
                onCancel: {
                    viewModel.cancelEditing()
                }
            )
        }
        .task {
            viewModel.load()
        }
    }

    private var filterSection: some View {
        SharedCard {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SharedSectionHeader("任务视图", subtitle: "计划视图按日期分组，列表视图保留快速操作")

                Picker("展示方式", selection: $viewModel.displayMode) {
                    ForEach(PlanningViewModel.DisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Picker("计划层级", selection: $viewModel.selectedPlanLevel) {
                    ForEach(PlanLevel.allCases, id: \.self) { level in
                        Text(level.title).tag(level)
                    }
                }
                .pickerStyle(.segmented)

                filterRow(
                    title: "状态筛选",
                    symbolName: "line.3.horizontal.decrease.circle",
                    menuSystemImage: "slider.horizontal.3",
                    selectedText: viewModel.selectedStatusFilter.title
                ) {
                    Picker("状态筛选", selection: $viewModel.selectedStatusFilter) {
                        ForEach(PlanningViewModel.StatusFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                }

                filterRow(
                    title: "日期范围",
                    symbolName: "calendar",
                    menuSystemImage: "calendar",
                    selectedText: viewModel.dateRangeFilter.title
                ) {
                    Picker("日期范围", selection: $viewModel.dateRangeFilter) {
                        ForEach(PlanningViewModel.DateRangeFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                }

                if viewModel.dateRangeFilter == .custom {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        DatePicker("开始日期", selection: $viewModel.customDateRangeStart, displayedComponents: .date)
                        DatePicker("结束日期", selection: $viewModel.customDateRangeEnd, displayedComponents: .date)
                    }
                    .font(AppTypography.body)
                }
            }
        }
    }

    @ViewBuilder
    private var taskContentSection: some View {
        switch viewModel.displayMode {
        case .plan:
            planTaskSection
        case .list:
            listTaskSection
        }
    }

    private var listTaskSection: some View {
        SharedCard {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SharedSectionHeader("任务清单", subtitle: viewModel.listSubtitle)

                if viewModel.isLoading {
                    SharedLoadingStateView(title: "正在加载任务…")
                } else if viewModel.loadErrorMessage != nil {
                    EmptyView()
                } else if viewModel.sections.isEmpty {
                    SharedEmptyStateView(
                        title: viewModel.emptyStateTitle,
                        message: viewModel.emptyStateMessage,
                        symbolName: "tray"
                    )
                } else {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        ForEach(viewModel.sections) { section in
                            statusSectionView(section)
                        }
                    }
                }
            }
        }
    }

    private var planTaskSection: some View {
        SharedCard {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SharedSectionHeader("计划视图", subtitle: viewModel.planSubtitle)

                if viewModel.isLoading {
                    SharedLoadingStateView(title: "正在加载任务…")
                } else if viewModel.loadErrorMessage != nil {
                    EmptyView()
                } else if viewModel.planSections.isEmpty {
                    SharedEmptyStateView(
                        title: viewModel.emptyStateTitle,
                        message: viewModel.emptyStateMessage,
                        symbolName: "tray"
                    )
                } else {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        ForEach(viewModel.planSections) { section in
                            planSectionView(section)
                        }
                    }
                }
            }
        }
    }

    private func statusSectionView(_ section: PlanningViewModel.StatusSection) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SharedSectionHeader(section.status.title, subtitle: "\(section.tasks.count) 条") {
                SharedStatusBadge(
                    text: section.status.title,
                    colorToken: section.status.colorToken,
                    symbolName: section.status.symbolName
                )
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ForEach(section.tasks, id: \.id) { task in
                    PlanningTaskRow(
                        task: task,
                        calendar: calendar,
                        showsQuickActions: true,
                        onEdit: { viewModel.startEdit(task) },
                        onDone: { viewModel.markDone(task) },
                        onPostpone: { viewModel.postpone(task) },
                        onCancel: { viewModel.cancel(task) }
                    )
                }
            }
        }
    }

    private func planSectionView(_ section: PlanningViewModel.PlanSection) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SharedSectionHeader(section.title, subtitle: "\(section.tasks.count) 条")

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ForEach(section.tasks, id: \.id) { task in
                    PlanningTaskRow(
                        task: task,
                        calendar: calendar,
                        showsQuickActions: false,
                        onEdit: { viewModel.startEdit(task) },
                        onDone: {},
                        onPostpone: {},
                        onCancel: {}
                    )
                }
            }
        }
    }

    private func filterRow<Content: View>(
        title: String,
        symbolName: String,
        menuSystemImage: String,
        selectedText: String,
        @ViewBuilder menuContent: @escaping () -> Content
    ) -> some View {
        HStack {
            SharedTag(text: selectedText, colorToken: .indigo, symbolName: symbolName)
            Spacer()
            Menu {
                menuContent()
            } label: {
                Label(title, systemImage: menuSystemImage)
                    .font(AppTypography.body.weight(.semibold))
            }
        }
    }
}

private struct PlanningTaskRow: View {
    let task: TaskItem
    let calendar: Calendar
    let showsQuickActions: Bool
    let onEdit: () -> Void
    let onDone: () -> Void
    let onPostpone: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SharedListRow(
                        title: task.title,
                        subtitle: subtitle,
                        symbolName: task.status.symbolName,
                        colorToken: task.status.colorToken,
                        badgeText: task.status.title
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.sm) {
                            SharedTag(text: task.planLevel.title + "计划", colorToken: .slate)
                            if let scheduleText {
                                SharedTag(text: scheduleText, colorToken: .blue, symbolName: "calendar")
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityHint("打开任务编辑表单")

            if showsQuickActions && canTransition {
                HStack(spacing: AppSpacing.sm) {
                    actionButton("完成", symbol: "checkmark.circle.fill", color: .green, action: onDone)
                    actionButton("延期", symbol: "arrow.uturn.forward.circle", color: .brown, action: onPostpone)
                    actionButton("取消", symbol: "xmark.circle.fill", color: .red, action: onCancel)
                }
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let detail = task.detail, !detail.isEmpty {
            parts.append(detail)
        }
        if let scheduleText {
            parts.append(scheduleText)
        }
        return parts.isEmpty ? "点击可编辑详细信息" : parts.joined(separator: " · ")
    }

    private var scheduleText: String? {
        guard let targetDate = task.scheduledAt else { return nil }

        if task.isAllDay {
            return targetDate.formatted(.dateTime.month().day())
        }

        if calendar.isDateInToday(targetDate) {
            return targetDate.formatted(date: .omitted, time: .shortened)
        }

        return targetDate.formatted(.dateTime.month().day().hour().minute())
    }

    private var canTransition: Bool {
        task.status == .todo || task.status == .postponed
    }

    private func actionButton(_ title: String, symbol: String, color: AppColorToken, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(AppTypography.caption.weight(.semibold))
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(color.color)
    }
}
