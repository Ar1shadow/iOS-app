import SwiftUI

struct PlanningTaskFormView: View {
    let editor: PlanningTaskEditor
    let onSave: (PlanningTaskDraft) -> String?
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var detail: String
    @State private var planLevel: PlanLevel
    @State private var includesStartAt: Bool
    @State private var startAt: Date
    @State private var includesDueAt: Bool
    @State private var dueAt: Date
    @State private var isAllDay: Bool
    @State private var errorMessage: String?

    init(
        editor: PlanningTaskEditor,
        onSave: @escaping (PlanningTaskDraft) -> String?,
        onCancel: @escaping () -> Void
    ) {
        self.editor = editor
        self.onSave = onSave
        self.onCancel = onCancel

        let startValue = editor.draft.startAt ?? Date()
        let dueValue = editor.draft.dueAt ?? editor.draft.startAt ?? Date()

        _title = State(initialValue: editor.draft.title)
        _detail = State(initialValue: editor.draft.detail)
        _planLevel = State(initialValue: editor.draft.planLevel)
        _includesStartAt = State(initialValue: editor.draft.startAt != nil)
        _startAt = State(initialValue: startValue)
        _includesDueAt = State(initialValue: editor.draft.dueAt != nil)
        _dueAt = State(initialValue: dueValue)
        _isAllDay = State(initialValue: editor.draft.isAllDay)
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
                    TextField("标题", text: $title)

                    TextField("详情", text: $detail, axis: .vertical)
                        .lineLimit(2 ... 4)

                    Picker("计划层级", selection: $planLevel) {
                        ForEach(PlanLevel.allCases, id: \.self) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    
                    if editor.task != nil {
                        LabeledContent("状态") {
                            SharedStatusBadge(
                                text: editor.draft.status.title,
                                colorToken: editor.draft.status.colorToken,
                                symbolName: editor.draft.status.symbolName
                            )
                        }
                    } else {
                        LabeledContent("状态") {
                            SharedStatusBadge(
                                text: TaskStatus.todo.title,
                                colorToken: TaskStatus.todo.colorToken,
                                symbolName: TaskStatus.todo.symbolName
                            )
                        }
                    }
                }

                Section("时间") {
                    Toggle("全天", isOn: $isAllDay)
                        .disabled(!includesStartAt && !includesDueAt)

                    Toggle("设置开始时间", isOn: $includesStartAt)
                    if includesStartAt {
                        datePicker("开始", selection: $startAt)
                    }

                    Toggle("设置截止时间", isOn: $includesDueAt)
                    if includesDueAt {
                        datePicker("截止", selection: $dueAt)
                    }
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
                        save()
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }

    @ViewBuilder
    private func datePicker(_ title: String, selection: Binding<Date>) -> some View {
        if isAllDay {
            DatePicker(title, selection: selection, displayedComponents: .date)
        } else {
            DatePicker(title, selection: selection, displayedComponents: [.date, .hourAndMinute])
        }
    }

    private func save() {
        let draft = PlanningTaskDraft(
            title: title,
            detail: detail,
            planLevel: planLevel,
            status: editor.draft.status,
            startAt: includesStartAt ? startAt : nil,
            dueAt: includesDueAt ? dueAt : nil,
            isAllDay: (includesStartAt || includesDueAt) ? isAllDay : false
        )

        if let errorMessage = onSave(draft) {
            self.errorMessage = errorMessage
            return
        }

        dismiss()
    }
}
