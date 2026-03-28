import XCTest
@testable import CoupleLife

@MainActor
final class CalendarDayDetailViewModelTests: XCTestCase {
    func testLoadBuildsTypeSectionsAndAppliesFilter() {
        let calendar = fixedCalendar()
        let day = makeDate(year: 2026, month: 3, day: 28, hour: 9, minute: 0, calendar: calendar)
        let service = StubCalendarDayRecordService(
            records: [
                Record(type: .water, note: "Morning", startAt: day, ownerUserId: "local"),
                Record(type: .bowelMovement, note: "Lunch", startAt: day.addingTimeInterval(3_600), ownerUserId: "local"),
                Record(type: .water, note: "Afternoon", startAt: day.addingTimeInterval(7_200), ownerUserId: "local")
            ]
        )
        let viewModel = CalendarDayDetailViewModel(
            date: day,
            subtitle: "2026年3月28日 星期六",
            service: service,
            calendar: calendar,
            onRecordsChanged: {}
        )

        viewModel.load()

        XCTAssertEqual(viewModel.sections.count, 2)
        XCTAssertEqual(viewModel.sections.first?.type, .water)
        XCTAssertEqual(viewModel.sections.first?.records.count, 2)

        viewModel.selectedFilter = .type(.bowelMovement)

        XCTAssertEqual(viewModel.sections.count, 1)
        XCTAssertEqual(viewModel.sections.first?.type, .bowelMovement)
        XCTAssertEqual(viewModel.sections.first?.records.count, 1)
    }

    func testQuickCheckInReloadsRecordsAndNotifiesParent() {
        let calendar = fixedCalendar()
        let day = makeDate(year: 2026, month: 3, day: 28, hour: 9, minute: 0, calendar: calendar)
        let service = StubCalendarDayRecordService(records: [])
        var reloadNotifications = 0
        let viewModel = CalendarDayDetailViewModel(
            date: day,
            subtitle: "2026年3月28日 星期六",
            service: service,
            calendar: calendar,
            onRecordsChanged: { reloadNotifications += 1 }
        )

        viewModel.load()
        viewModel.quickCheckIn(type: .water)

        XCTAssertEqual(service.quickCheckInTypes, [.water])
        XCTAssertEqual(viewModel.records.count, 1)
        XCTAssertEqual(reloadNotifications, 1)
    }

    private func fixedCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int, calendar: Calendar) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ).date!
    }
}

private final class StubCalendarDayRecordService: CalendarDayRecordManaging {
    private(set) var storedRecords: [Record]
    private(set) var quickCheckInTypes: [RecordType] = []

    init(records: [Record]) {
        self.storedRecords = records
    }

    func records(for day: Date) throws -> [Record] {
        storedRecords.sorted { $0.startAt > $1.startAt }
    }

    func makeDraft(for selectedDay: Date, type: RecordType) -> CalendarDayRecordDraft {
        CalendarDayRecordDraft(type: type, startAt: selectedDay)
    }

    func makeDraft(for record: Record) -> CalendarDayRecordDraft {
        CalendarDayRecordDraft(type: record.type, startAt: record.startAt)
    }

    func createRecord(from draft: CalendarDayRecordDraft) throws -> Record {
        let record = Record(type: draft.type, startAt: draft.startAt, ownerUserId: "local")
        storedRecords.append(record)
        return record
    }

    func updateRecord(_ record: Record, from draft: CalendarDayRecordDraft) throws {}

    func createQuickCheckIn(type: RecordType, on selectedDay: Date) throws -> Record {
        quickCheckInTypes.append(type)
        let record = Record(type: type, startAt: selectedDay, ownerUserId: "local")
        storedRecords.append(record)
        return record
    }

    func deleteRecord(_ record: Record) throws {
        storedRecords.removeAll { $0.id == record.id }
    }
}
