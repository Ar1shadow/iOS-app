import XCTest
@testable import CoupleLife

final class CalendarMonthGridBuilderTests: XCTestCase {
    func testBuildMonthProducesFiveCompleteWeeksWhenMonthFits() {
        let grid = CalendarMonthGridBuilder.buildMonth(
            containing: makeDate(year: 2024, month: 1, day: 15),
            calendar: fixedCalendar()
        )

        XCTAssertEqual(grid.days.count, 35)
        XCTAssertEqual(grid.days.first?.date, makeDate(year: 2024, month: 1, day: 1))
        XCTAssertEqual(grid.days.last?.date, makeDate(year: 2024, month: 2, day: 4))
        XCTAssertEqual(grid.days.filter(\.isInDisplayedMonth).count, 31)
    }

    func testBuildMonthProducesSixWeeksWhenLeadingAndTrailingDaysAreNeeded() {
        let grid = CalendarMonthGridBuilder.buildMonth(
            containing: makeDate(year: 2025, month: 6, day: 10),
            calendar: fixedCalendar()
        )

        XCTAssertEqual(grid.days.count, 42)
        XCTAssertEqual(grid.days.first?.date, makeDate(year: 2025, month: 5, day: 26))
        XCTAssertEqual(grid.days.last?.date, makeDate(year: 2025, month: 7, day: 6))
        XCTAssertEqual(grid.days.filter(\.isInDisplayedMonth).count, 30)
    }

    func testBuildMonthMarksDaysOutsideDisplayedMonth() {
        let grid = CalendarMonthGridBuilder.buildMonth(
            containing: makeDate(year: 2024, month: 2, day: 20),
            calendar: fixedCalendar()
        )

        XCTAssertEqual(grid.days.first?.date, makeDate(year: 2024, month: 1, day: 29))
        XCTAssertFalse(grid.days.first?.isInDisplayedMonth ?? true)
        XCTAssertEqual(grid.days[3].date, makeDate(year: 2024, month: 2, day: 1))
        XCTAssertTrue(grid.days[3].isInDisplayedMonth)
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
