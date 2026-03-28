import Foundation

struct CalendarRecordSummary {
    let visibleRange: DateInterval
    let markerDates: Set<Date>
    let recordsByDay: [Date: [Record]]

    func records(on date: Date, calendar: Calendar) -> [Record] {
        recordsByDay[calendar.startOfDay(for: date)] ?? []
    }

    static func empty(range: DateInterval) -> CalendarRecordSummary {
        CalendarRecordSummary(visibleRange: range, markerDates: [], recordsByDay: [:])
    }
}

protocol CalendarRecordSummaryService {
    func load(range: DateInterval, ownerUserId: String) throws -> CalendarRecordSummary
}

struct DefaultCalendarRecordSummaryService: CalendarRecordSummaryService {
    private let recordRepository: any RecordRepository
    private let calendar: Calendar

    init(recordRepository: any RecordRepository, calendar: Calendar = .current) {
        self.recordRepository = recordRepository
        self.calendar = calendar
    }

    func load(range: DateInterval, ownerUserId: String) throws -> CalendarRecordSummary {
        let records = try recordRepository.records(from: range.start, to: range.end)
            .filter { $0.ownerUserId == ownerUserId }
            .sorted { $0.startAt < $1.startAt }

        var groupedRecords: [Date: [Record]] = [:]
        for record in records {
            let dayStart = calendar.startOfDay(for: record.startAt)
            groupedRecords[dayStart, default: []].append(record)
        }

        return CalendarRecordSummary(
            visibleRange: range,
            markerDates: Set(groupedRecords.keys),
            recordsByDay: groupedRecords
        )
    }
}
