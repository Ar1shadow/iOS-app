import SwiftUI

struct CalendarDayDetailView: View {
    @StateObject private var viewModel: CalendarDayDetailViewModel
    private let calendar: Calendar

    init(
        date: Date,
        subtitle: String,
        recordRepository: any RecordRepository,
        calendar: Calendar = .current,
        ownerUserId: String = CurrentUser.id,
        nowProvider: @escaping () -> Date = Date.init,
        onRecordsChanged: @escaping @MainActor () -> Void = {}
    ) {
        self.calendar = calendar
        let service = DefaultCalendarDayRecordService(
            recordRepository: recordRepository,
            calendar: calendar,
            ownerUserId: ownerUserId,
            nowProvider: nowProvider
        )
        _viewModel = StateObject(
            wrappedValue: CalendarDayDetailViewModel(
                date: date,
                subtitle: subtitle,
                service: service,
                calendar: calendar,
                onRecordsChanged: onRecordsChanged
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                quickCheckInSection

                if let loadErrorMessage = viewModel.loadErrorMessage {
                    SharedEmptyStateView(
                        title: "当天记录暂不可用",
                        message: loadErrorMessage,
                        symbolName: "exclamationmark.triangle"
                    )
                }

                recordsSection
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(AppColorToken.background.color.ignoresSafeArea())
        .navigationTitle(viewModel.date.formatted(.dateTime.month().day()))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.startAdd()
                } label: {
                    Label("新增记录", systemImage: "plus")
                }
            }
        }
        .sheet(item: $viewModel.editor) { editor in
            CalendarRecordFormView(
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

    private var quickCheckInSection: some View {
        SharedCard {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SharedSectionHeader("快捷打卡", subtitle: "为高频类型快速创建当天记录")

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.md), count: 2), spacing: AppSpacing.md) {
                    ForEach(viewModel.quickCheckInTypes, id: \.self) { type in
                        Button {
                            viewModel.quickCheckIn(type: type)
                        } label: {
                            CalendarQuickCheckInButton(type: type)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("今天默认使用当前时间，其他日期默认使用本地时间 12:00。")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColorToken.textSecondary.color)
            }
        }
    }

    private var recordsSection: some View {
        SharedCard {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SharedSectionHeader("当天记录", subtitle: viewModel.recordsSubtitle) {
                    Menu {
                        Picker("筛选类型", selection: $viewModel.selectedFilter) {
                            ForEach(viewModel.filterOptions) { option in
                                Text(option.title).tag(option)
                            }
                        }
                    } label: {
                        Label("筛选", systemImage: "line.3.horizontal.decrease.circle")
                            .font(AppTypography.body.weight(.semibold))
                    }
                }

                if viewModel.isLoading {
                    SharedLoadingStateView(title: "正在加载当天记录…")
                } else if viewModel.sections.isEmpty {
                    SharedEmptyStateView(
                        title: viewModel.emptyStateTitle,
                        message: viewModel.emptyStateMessage,
                        symbolName: "tray"
                    )
                } else {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        ForEach(viewModel.sections) { section in
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                SharedSectionHeader(section.type.visualStyle.title, subtitle: "\(section.records.count) 条") {
                                    SharedStatusBadge(
                                        text: section.type.visualStyle.title,
                                        colorToken: section.type.visualStyle.colorToken,
                                        symbolName: section.type.visualStyle.symbolName
                                    )
                                }

                                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                    ForEach(section.records, id: \.id) { record in
                                        CalendarDayRecordRow(
                                            record: record,
                                            calendar: calendar,
                                            onEdit: { viewModel.startEdit(record) },
                                            onDelete: { viewModel.delete(record) }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct CalendarQuickCheckInButton: View {
    let type: RecordType

    var body: some View {
        let style = type.visualStyle

        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Image(systemName: style.symbolName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(style.colorToken.color)
                .frame(width: 42, height: 42)
                .background(style.colorToken.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous))

            Text(style.title)
                .font(AppTypography.sectionTitle)
                .foregroundStyle(AppColorToken.textPrimary.color)

            Text("一键新增")
                .font(AppTypography.caption)
                .foregroundStyle(AppColorToken.textSecondary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(style.colorToken.color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                .stroke(style.colorToken.color.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct CalendarDayRecordRow: View {
    let record: Record
    let calendar: Calendar
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let style = record.type.visualStyle

        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                SharedListRow(
                    title: style.title,
                    subtitle: subtitleText,
                    symbolName: style.symbolName,
                    colorToken: style.colorToken,
                    badgeText: record.valueText
                )

                if !chips.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.sm) {
                            ForEach(chips, id: \.self) { chip in
                                SharedTag(text: chip, colorToken: .slate)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, AppSpacing.xs)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("编辑") {
                onEdit()
            }
            Button("删除", role: .destructive) {
                onDelete()
            }
        }
        .accessibilityHint("打开记录编辑表单")
    }

    private var subtitleText: String {
        var parts = [timeRangeText]
        if let note = record.note, !note.isEmpty {
            parts.append(note)
        }
        return parts.joined(separator: " · ")
    }

    private var chips: [String] {
        var values = record.tags
        values.append(record.visibility.shortLabel)
        return values
    }

    private var timeRangeText: String {
        if let endAt = record.endAt {
            return "\(formattedTime(record.startAt)) - \(formattedTime(endAt))"
        }
        return formattedTime(record.startAt)
    }

    private func formattedTime(_ date: Date) -> String {
        if calendar.isDate(date, inSameDayAs: record.startAt) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct CalendarRecordFormView: View {
    let editor: CalendarDayRecordEditor
    let onSave: (CalendarDayRecordDraft) -> String?
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var type: RecordType
    @State private var note: String
    @State private var tagsRaw: String
    @State private var startAt: Date
    @State private var includesEndAt: Bool
    @State private var endAt: Date
    @State private var valueText: String
    @State private var visibility: Visibility
    @State private var errorMessage: String?

    init(
        editor: CalendarDayRecordEditor,
        onSave: @escaping (CalendarDayRecordDraft) -> String?,
        onCancel: @escaping () -> Void
    ) {
        self.editor = editor
        self.onSave = onSave
        self.onCancel = onCancel
        _type = State(initialValue: editor.draft.type)
        _note = State(initialValue: editor.draft.note)
        _tagsRaw = State(initialValue: editor.draft.tagsRaw)
        _startAt = State(initialValue: editor.draft.startAt)
        _includesEndAt = State(initialValue: editor.draft.endAt != nil)
        _endAt = State(initialValue: editor.draft.endAt ?? editor.draft.startAt)
        _valueText = State(initialValue: editor.draft.valueText)
        _visibility = State(initialValue: editor.draft.visibility)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColorToken.red.color)
                    }
                }

                Section("基本信息") {
                    Picker("类型", selection: $type) {
                        ForEach(RecordType.allCases, id: \.self) { type in
                            Text(type.visualStyle.title).tag(type)
                        }
                    }

                    TextField("备注", text: $note, axis: .vertical)
                        .lineLimit(2 ... 4)

                    TextField("标签（逗号分隔）", text: $tagsRaw)
                    TextField("状态/数值", text: $valueText)
                }

                Section("时间") {
                    DatePicker("开始时间", selection: $startAt)

                    Toggle("设置结束时间", isOn: $includesEndAt)

                    if includesEndAt {
                        DatePicker("结束时间", selection: $endAt)
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColorToken.red.color)
                    }
                }

                Section("可见性") {
                    Picker("可见性", selection: $visibility) {
                        ForEach(Visibility.allCases, id: \.self) { visibility in
                            Text(visibility.formTitle).tag(visibility)
                        }
                    }

                    Text("默认仅自己可见；共享策略仍留在后续任务中实现。")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColorToken.textSecondary.color)
                }
            }
            .navigationTitle(editor.title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        onCancel()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(editor.saveButtonTitle) {
                        let draft = CalendarDayRecordDraft(
                            type: type,
                            note: note,
                            tagsRaw: tagsRaw,
                            startAt: startAt,
                            endAt: includesEndAt ? endAt : nil,
                            valueText: valueText,
                            visibility: visibility
                        )

                        if let errorMessage = onSave(draft) {
                            self.errorMessage = errorMessage
                        } else {
                            dismiss()
                        }
                    }
                    .disabled(validationMessage != nil)
                }
            }
        }
    }

    private var validationMessage: String? {
        guard includesEndAt, endAt < startAt else {
            return nil
        }
        return "结束时间不能早于开始时间。"
    }
}

private extension Visibility {
    var shortLabel: String {
        switch self {
        case .private:
            return "私密"
        case .coupleShared:
            return "共享"
        }
    }

    var formTitle: String {
        switch self {
        case .private:
            return "仅自己可见"
        case .coupleShared:
            return "共享给伴侣"
        }
    }
}
