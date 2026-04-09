import Foundation

protocol CalendarDayRecordManaging {
    func records(for day: Date) throws -> [Record]
    func makeDraft(for selectedDay: Date, type: RecordType) -> CalendarDayRecordDraft
    func makeDraft(for record: Record) -> CalendarDayRecordDraft
    func createRecord(from draft: CalendarDayRecordDraft) throws -> Record
    func updateRecord(_ record: Record, from draft: CalendarDayRecordDraft) throws
    func createQuickCheckIn(type: RecordType, on selectedDay: Date) throws -> Record
    func deleteRecord(_ record: Record) throws
}

enum CalendarDayRecordValidationError: LocalizedError, Equatable {
    case endBeforeStart

    var errorDescription: String? {
        switch self {
        case .endBeforeStart:
            return "结束时间不能早于开始时间。"
        }
    }
}

struct CalendarDayRecordDraft: Equatable {
    var type: RecordType
    var note: String
    var tagsRaw: String
    var startAt: Date
    var endAt: Date?
    var valueText: String
    var visibility: Visibility
    var source: DataSource

    init(
        type: RecordType,
        note: String = "",
        tagsRaw: String = "",
        startAt: Date,
        endAt: Date? = nil,
        valueText: String = "",
        visibility: Visibility = .private,
        source: DataSource = .manual
    ) {
        self.type = type
        self.note = note
        self.tagsRaw = tagsRaw
        self.startAt = startAt
        self.endAt = endAt
        self.valueText = valueText
        self.visibility = visibility
        self.source = source
    }

    var normalizedNote: String? {
        note.trimmedNilIfEmpty
    }

    var normalizedTagsRaw: String {
        tagsRaw
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ",")
    }

    var normalizedValueText: String? {
        valueText.trimmedNilIfEmpty
    }
}

final class DefaultCalendarDayRecordService: CalendarDayRecordManaging {
    private let recordRepository: any RecordRepository
    private let calendar: Calendar
    private let ownerUserId: String
    private let nowProvider: () -> Date

    init(
        recordRepository: any RecordRepository,
        calendar: Calendar = .current,
        ownerUserId: String,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.recordRepository = recordRepository
        self.calendar = calendar
        self.ownerUserId = ownerUserId
        self.nowProvider = nowProvider
    }

    func records(for day: Date) throws -> [Record] {
        let interval = dayInterval(for: day)
        return try recordRepository
            .records(from: interval.start, to: interval.end)
            .filter { $0.ownerUserId == ownerUserId }
    }

    func makeDraft(for selectedDay: Date, type: RecordType = .custom) -> CalendarDayRecordDraft {
        CalendarDayRecordDraft(
            type: type,
            startAt: defaultStartDate(for: selectedDay),
            visibility: VisibilityPolicy.record(type: type).sanitized(.private)
        )
    }

    func makeDraft(for record: Record) -> CalendarDayRecordDraft {
        CalendarDayRecordDraft(
            type: record.type,
            note: record.note ?? "",
            tagsRaw: record.tagsRaw ?? "",
            startAt: record.startAt,
            endAt: record.endAt,
            valueText: record.valueText ?? "",
            visibility: record.visibility,
            source: record.source
        )
    }

    func createRecord(from draft: CalendarDayRecordDraft) throws -> Record {
        try validate(draft)
        let sanitizedVisibility = VisibilityPolicy.record(type: draft.type).sanitized(draft.visibility)

        let record = Record(
            type: draft.type,
            note: draft.normalizedNote,
            tagsRaw: draft.normalizedTagsRaw,
            startAt: draft.startAt,
            endAt: draft.endAt,
            valueText: draft.normalizedValueText,
            ownerUserId: ownerUserId,
            visibility: sanitizedVisibility,
            source: draft.source
        )
        try recordRepository.create(record)
        return record
    }

    func updateRecord(_ record: Record, from draft: CalendarDayRecordDraft) throws {
        try validate(draft)
        let sanitizedVisibility = VisibilityPolicy.record(type: draft.type).sanitized(draft.visibility)

        record.type = draft.type
        record.note = draft.normalizedNote
        record.tagsRaw = draft.normalizedTagsRaw
        record.startAt = draft.startAt
        record.endAt = draft.endAt
        record.valueText = draft.normalizedValueText
        record.visibility = sanitizedVisibility
        record.source = draft.source
        try recordRepository.update(record)
    }

    func createQuickCheckIn(type: RecordType, on selectedDay: Date) throws -> Record {
        try createRecord(
            from: CalendarDayRecordDraft(
                type: type,
                startAt: defaultStartDate(for: selectedDay)
            )
        )
    }

    func deleteRecord(_ record: Record) throws {
        try recordRepository.delete(record)
    }

    func validate(_ draft: CalendarDayRecordDraft) throws {
        if let endAt = draft.endAt, endAt < draft.startAt {
            throw CalendarDayRecordValidationError.endBeforeStart
        }
    }

    private func dayInterval(for day: Date) -> DateInterval {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    private func defaultStartDate(for selectedDay: Date) -> Date {
        let now = nowProvider()
        if calendar.isDate(selectedDay, inSameDayAs: now) {
            return now
        }

        let startOfDay = calendar.startOfDay(for: selectedDay)
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startOfDay) ?? startOfDay
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
