import XCTest
@testable import CoupleLife

@MainActor
final class CalendarViewModelTests: XCTestCase {
    func testMonthShiftPreservesAnchoredDayAcrossShorterMonth() {
        let calendar = fixedCalendar()
        let viewModel = CalendarViewModel(
            service: StubCalendarRecordSummaryService(),
            calendar: calendar,
            ownerUserId: "local",
            nowProvider: { self.makeDate(year: 2024, month: 1, day: 31) }
        )

        viewModel.shiftVisiblePeriod(by: 1)
        XCTAssertEqual(viewModel.selectedDate, makeDate(year: 2024, month: 2, day: 29))

        viewModel.shiftVisiblePeriod(by: -1)
        XCTAssertEqual(viewModel.selectedDate, makeDate(year: 2024, month: 1, day: 31))
    }

    private func fixedCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        let components = DateComponents(
            calendar: fixedCalendar(),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day
        )
        return components.date!
    }
}

private struct StubCalendarRecordSummaryService: CalendarRecordSummaryService {
    func load(range: DateInterval, ownerUserId: String) throws -> CalendarRecordSummary {
        .empty(range: range)
    }
}
