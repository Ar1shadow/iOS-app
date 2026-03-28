import Foundation

@MainActor
final class CalendarDayDetailViewModel: ObservableObject {
    enum RecordFilter: Hashable, Identifiable {
        case all
        case type(RecordType)

        var id: String {
            switch self {
            case .all:
                return "all"
            case let .type(type):
                return type.rawValue
            }
        }

        var title: String {
            switch self {
            case .all:
                return "全部类型"
            case let .type(type):
                return type.visualStyle.title
            }
        }
    }

    struct Section: Identifiable {
        let type: RecordType
        let records: [Record]

        var id: String { type.rawValue }
    }

    let date: Date
    let subtitle: String

    @Published private(set) var records: [Record] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadErrorMessage: String?
    @Published var selectedFilter: RecordFilter = .all
    @Published var editor: CalendarDayRecordEditor?

    private let service: any CalendarDayRecordManaging
    private let calendar: Calendar
    private let onRecordsChanged: @MainActor () -> Void

    init(
        date: Date,
        subtitle: String,
        service: any CalendarDayRecordManaging,
        calendar: Calendar = .current,
        onRecordsChanged: @escaping @MainActor () -> Void
    ) {
        self.date = date
        self.subtitle = subtitle
        self.service = service
        self.calendar = calendar
        self.onRecordsChanged = onRecordsChanged
    }

    var filterOptions: [RecordFilter] {
        [.all] + RecordType.allCases.map { .type($0) }
    }

    var quickCheckInTypes: [RecordType] {
        [.water, .bowelMovement]
    }

    var sections: [Section] {
        let groupedRecords = Dictionary(grouping: filteredRecords, by: \.type)
        return RecordType.allCases.compactMap { type in
            guard let typeRecords = groupedRecords[type], !typeRecords.isEmpty else {
                return nil
            }
            return Section(type: type, records: typeRecords)
        }
    }

    var recordsSubtitle: String {
        switch selectedFilter {
        case .all:
            return records.isEmpty ? "暂无记录" : "共 \(records.count) 条记录，按类型分组"
        case let .type(type):
            return "\(type.visualStyle.title) · \(filteredRecords.count) 条"
        }
    }

    var emptyStateTitle: String {
        switch selectedFilter {
        case .all:
            return "当天还没有记录"
        case let .type(type):
            return "当天还没有\(type.visualStyle.title)记录"
        }
    }

    var emptyStateMessage: String {
        "可以先用快捷打卡，或通过右上角新增一条记录。"
    }

    func load() {
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedRecords = try service.records(for: date)
            records = loadedRecords.sorted(by: sortRecords)
            loadErrorMessage = nil
        } catch {
            records = []
            loadErrorMessage = "当天记录加载失败，请稍后重试。"
        }
    }

    func startAdd(type: RecordType = .custom) {
        editor = CalendarDayRecordEditor(
            title: "新增记录",
            saveButtonTitle: "保存",
            record: nil,
            draft: service.makeDraft(for: date, type: type)
        )
    }

    func startEdit(_ record: Record) {
        editor = CalendarDayRecordEditor(
            title: "编辑记录",
            saveButtonTitle: "更新",
            record: record,
            draft: service.makeDraft(for: record)
        )
    }

    func cancelEditing() {
        editor = nil
    }

    func save(draft: CalendarDayRecordDraft) -> String? {
        guard let editor else {
            return "当前没有可保存的记录。"
        }

        do {
            if let record = editor.record {
                try service.updateRecord(record, from: draft)
            } else {
                _ = try service.createRecord(from: draft)
            }
            self.editor = nil
            load()
            onRecordsChanged()
            return nil
        } catch let validationError as CalendarDayRecordValidationError {
            return validationError.errorDescription ?? "记录校验失败。"
        } catch {
            return "保存记录失败，请稍后重试。"
        }
    }

    func quickCheckIn(type: RecordType) {
        do {
            _ = try service.createQuickCheckIn(type: type, on: date)
            load()
            onRecordsChanged()
        } catch {
            loadErrorMessage = "快捷打卡失败，请稍后重试。"
        }
    }

    func delete(_ record: Record) {
        do {
            try service.deleteRecord(record)
            if editor?.record?.id == record.id {
                editor = nil
            }
            load()
            onRecordsChanged()
        } catch {
            loadErrorMessage = "删除记录失败，请稍后重试。"
        }
    }

    private var filteredRecords: [Record] {
        switch selectedFilter {
        case .all:
            return records
        case let .type(type):
            return records.filter { $0.type == type }
        }
    }

    private func sortRecords(lhs: Record, rhs: Record) -> Bool {
        if lhs.startAt == rhs.startAt {
            return lhs.createdAt > rhs.createdAt
        }
        return lhs.startAt > rhs.startAt
    }
}

struct CalendarDayRecordEditor: Identifiable {
    let id = UUID()
    let title: String
    let saveButtonTitle: String
    let record: Record?
    let draft: CalendarDayRecordDraft
}
