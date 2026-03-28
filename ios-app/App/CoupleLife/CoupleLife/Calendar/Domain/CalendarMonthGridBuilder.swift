import Foundation

struct CalendarMonthGrid {
    let monthStart: Date
    let days: [CalendarMonthGridDay]

    var weeks: [[CalendarMonthGridDay]] {
        stride(from: 0, to: days.count, by: 7).map { startIndex in
            Array(days[startIndex ..< min(startIndex + 7, days.count)])
        }
    }
}

struct CalendarMonthGridDay: Equatable, Identifiable {
    let date: Date
    let isInDisplayedMonth: Bool

    var id: Date { date }
}

enum CalendarMonthGridBuilder {
    static func buildMonth(containing date: Date, calendar: Calendar) -> CalendarMonthGrid {
        let monthInterval = calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
        let monthStart = calendar.startOfDay(for: monthInterval.start)
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 0

        let leadingDays = normalizedWeekdayOffset(
            weekday: calendar.component(.weekday, from: monthStart),
            firstWeekday: calendar.firstWeekday
        )
        let visibleStart = calendar.date(byAdding: .day, value: -leadingDays, to: monthStart) ?? monthStart

        let lastDayInMonth = calendar.date(byAdding: .day, value: max(daysInMonth - 1, 0), to: monthStart) ?? monthStart
        let trailingDays = normalizedWeekdayOffset(
            weekday: calendar.firstWeekday + 6,
            firstWeekday: calendar.component(.weekday, from: lastDayInMonth)
        )
        let visibleDayCount = leadingDays + daysInMonth + trailingDays

        let days = (0 ..< visibleDayCount).compactMap { offset -> CalendarMonthGridDay? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: visibleStart) else {
                return nil
            }
            return CalendarMonthGridDay(
                date: day,
                isInDisplayedMonth: calendar.isDate(day, equalTo: monthStart, toGranularity: .month)
            )
        }

        return CalendarMonthGrid(monthStart: monthStart, days: days)
    }

    private static func normalizedWeekdayOffset(weekday: Int, firstWeekday: Int) -> Int {
        (weekday - firstWeekday + 7) % 7
    }
}
