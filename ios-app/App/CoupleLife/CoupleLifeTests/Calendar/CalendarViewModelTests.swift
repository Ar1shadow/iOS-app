import XCTest
@testable import CoupleLife

@MainActor
final class CalendarViewModelTests: XCTestCase {
    func testMonthShiftPreservesAnchoredDayAcrossShorterMonth() {
        let calendar = fixedCalendar()
        let viewModel = CalendarViewModel(
            service: EmptyCalendarRecordSummaryService(),
            calendar: calendar,
            ownerUserId: "local",
            nowProvider: { self.makeDate(year: 2024, month: 1, day: 31) }
        )

        viewModel.shiftVisiblePeriod(by: 1)
        XCTAssertEqual(viewModel.selectedDate, makeDate(year: 2024, month: 2, day: 29))

        viewModel.shiftVisiblePeriod(by: -1)
        XCTAssertEqual(viewModel.selectedDate, makeDate(year: 2024, month: 1, day: 31))
    }

    func testReloadFailureSetsErrorAndFallsBackToEmptySummary() async {
        let calendar = fixedCalendar()
        let currentDate = makeDate(year: 2024, month: 1, day: 31)
        let viewModel = CalendarViewModel(
            service: ThrowingCalendarRecordSummaryService(),
            calendar: calendar,
            ownerUserId: "local",
            nowProvider: { currentDate }
        )

        await viewModel.reload()

        let expectedRange = visibleRange(for: currentDate, calendar: calendar)
        XCTAssertEqual(viewModel.summary.visibleRange, expectedRange)
        XCTAssertTrue(viewModel.summary.markerDates.isEmpty)
        XCTAssertTrue(viewModel.selectedDayRecords.isEmpty)
        XCTAssertEqual(viewModel.loadErrorMessage, "日历摘要加载失败，请稍后重试。")
        XCTAssertFalse(viewModel.isLoading)
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

    private func visibleRange(for date: Date, calendar: Calendar) -> DateInterval {
        let grid = CalendarMonthGridBuilder.buildMonth(containing: date, calendar: calendar)
        let start = grid.days.first!.date
        let end = calendar.date(byAdding: .day, value: grid.days.count, to: start)!
        return DateInterval(start: start, end: end)
    }
}

private struct EmptyCalendarRecordSummaryService: CalendarRecordSummaryService {
    func load(range: DateInterval, ownerUserId: String) throws -> CalendarRecordSummary {
        .empty(range: range)
    }
}

private struct ThrowingCalendarRecordSummaryService: CalendarRecordSummaryService {
    func load(range: DateInterval, ownerUserId: String) throws -> CalendarRecordSummary {
        throw NSError(domain: "CalendarViewModelTests", code: 1)
    }
}
