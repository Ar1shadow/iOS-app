import XCTest
@testable import CoupleLife

final class CalendarRecordSummaryServiceTests: XCTestCase {
    func testLoadBuildsMarkersAndGroupsRecordsByDayForOwner() throws {
        let calendar = fixedCalendar()
        let day = makeDate(year: 2026, month: 3, day: 28, hour: 9)
        let dayStart = calendar.startOfDay(for: day)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let twoDaysLater = calendar.date(byAdding: .day, value: 2, to: dayStart)!

        let service = DefaultCalendarRecordSummaryService(
            recordRepository: InMemoryCalendarRecordRepository(records: [
                Record(type: .water, startAt: calendar.date(byAdding: .hour, value: 1, to: dayStart)!, ownerUserId: "local"),
                Record(type: .sleep, startAt: calendar.date(byAdding: .hour, value: 12, to: dayStart)!, ownerUserId: "local"),
                Record(type: .activity, startAt: calendar.date(byAdding: .hour, value: 8, to: nextDay)!, ownerUserId: "local"),
                Record(type: .water, startAt: calendar.date(byAdding: .hour, value: 9, to: nextDay)!, ownerUserId: "other"),
                Record(type: .water, startAt: calendar.date(byAdding: .hour, value: 9, to: twoDaysLater)!, ownerUserId: "local")
            ]),
            calendar: calendar
        )

        let summary = try service.load(
            range: DateInterval(start: dayStart, end: twoDaysLater),
            ownerUserId: "local"
        )

        XCTAssertEqual(summary.markerDates, [dayStart, nextDay])
        XCTAssertEqual(summary.recordsByDay[dayStart]?.count, 2)
        XCTAssertEqual(summary.recordsByDay[nextDay]?.count, 1)
        XCTAssertEqual(summary.recordsByDay[nextDay]?.first?.type, .activity)
        XCTAssertNil(summary.recordsByDay[twoDaysLater])
    }

    private func fixedCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        let components = DateComponents(
            calendar: fixedCalendar(),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day,
            hour: hour
        )
        return components.date!
    }
}

private final class InMemoryCalendarRecordRepository: RecordRepository {
    private let items: [Record]

    init(records: [Record]) {
        self.items = records
    }

    func create(_ record: Record) throws {}
    func update(_ record: Record) throws {}
    func delete(_ record: Record) throws {}

    func records(from start: Date, to end: Date) throws -> [Record] {
        items.filter { $0.startAt >= start && $0.startAt < end }
    }
}
