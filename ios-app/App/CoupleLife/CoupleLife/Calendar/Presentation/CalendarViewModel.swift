import Foundation

@MainActor
final class CalendarViewModel: ObservableObject {
    enum DisplayMode: String, CaseIterable, Identifiable {
        case month = "月"
        case week = "周"
        case day = "日"

        var id: Self { self }
    }

    @Published private(set) var displayMode: DisplayMode = .month
    @Published private(set) var selectedDate: Date
    @Published private(set) var summary: CalendarRecordSummary
    @Published private(set) var isLoading = false
    @Published private(set) var loadErrorMessage: String?

    private let service: any CalendarRecordSummaryService
    private let calendar: Calendar
    private let ownerUserId: String
    private var hasLoaded = false
    private var loadGeneration = 0

    init(
        service: any CalendarRecordSummaryService,
        calendar: Calendar = .current,
        ownerUserId: String,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.service = service
        self.calendar = calendar
        self.ownerUserId = ownerUserId

        let today = calendar.startOfDay(for: nowProvider())
        let initialRange = Self.visibleRange(for: today, mode: .month, calendar: calendar)
        self.selectedDate = today
        self.summary = .empty(range: initialRange)
    }

    var monthGrid: CalendarMonthGrid {
        CalendarMonthGridBuilder.buildMonth(containing: selectedDate, calendar: calendar)
    }

    var weekDates: [Date] {
        let interval = Self.visibleRange(for: selectedDate, mode: .week, calendar: calendar)
        return (0 ..< 7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: interval.start)
        }
    }

    var selectedDayRecords: [Record] {
        summary.records(on: selectedDate, calendar: calendar)
    }

    var headerTitle: String {
        switch displayMode {
        case .month:
            return format(selectedDate, dateFormat: "yyyy年M月")
        case .week:
            let interval = Self.visibleRange(for: selectedDate, mode: .week, calendar: calendar)
            let endDate = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            return "\(format(interval.start, dateFormat: "M月d日")) - \(format(endDate, dateFormat: "M月d日"))"
        case .day:
            return format(selectedDate, dateFormat: "M月d日 EEEE")
        }
    }

    var selectedDateSubtitle: String {
        format(selectedDate, dateFormat: "yyyy年M月d日 EEEE")
    }

    var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        guard !symbols.isEmpty else { return [] }
        let firstIndex = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await reload()
    }

    func reload() async {
        let range = Self.visibleRange(for: selectedDate, mode: displayMode, calendar: calendar)
        await load(range: range)
    }

    func setDisplayMode(_ mode: DisplayMode) {
        guard mode != displayMode else { return }
        displayMode = mode
        Task { await reload() }
    }

    func selectDate(_ date: Date) {
        let normalizedDate = calendar.startOfDay(for: date)
        guard normalizedDate != selectedDate else { return }
        selectedDate = normalizedDate

        let newRange = Self.visibleRange(for: normalizedDate, mode: displayMode, calendar: calendar)
        guard newRange != summary.visibleRange else { return }
        Task { await load(range: newRange) }
    }

    func shiftVisiblePeriod(by value: Int) {
        let component: Calendar.Component
        let amount: Int

        switch displayMode {
        case .month:
            component = .month
            amount = value
        case .week:
            component = .day
            amount = value * 7
        case .day:
            component = .day
            amount = value
        }

        guard let shiftedDate = calendar.date(byAdding: component, value: amount, to: selectedDate) else {
            return
        }

        selectedDate = calendar.startOfDay(for: shiftedDate)
        Task { await reload() }
    }

    func hasMarker(on date: Date) -> Bool {
        summary.markerDates.contains(calendar.startOfDay(for: date))
    }

    func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    func dayNumber(for date: Date) -> String {
        String(calendar.component(.day, from: date))
    }

    func shortDayLabel(for date: Date) -> String {
        format(date, dateFormat: "E d")
    }

    func shortDateLabel(for date: Date) -> String {
        format(date, dateFormat: "M月d日")
    }

    func fullDateLabel(for date: Date) -> String {
        format(date, dateFormat: "M月d日 EEEE")
    }

    func summaryBadgeText(for date: Date) -> String {
        let count = summary.records(on: date, calendar: calendar).count
        return count == 0 ? "无记录" : "\(count) 条记录"
    }

    private func load(range: DateInterval) async {
        loadGeneration += 1
        let currentGeneration = loadGeneration
        isLoading = true
        loadErrorMessage = nil

        do {
            await Task.yield()
            let loadedSummary = try service.load(range: range, ownerUserId: ownerUserId)
            guard currentGeneration == loadGeneration else { return }
            summary = loadedSummary
        } catch {
            guard currentGeneration == loadGeneration else { return }
            summary = .empty(range: range)
            loadErrorMessage = "日历摘要加载失败，请稍后重试。"
        }

        guard currentGeneration == loadGeneration else { return }
        isLoading = false
    }

    private func format(_ date: Date, dateFormat: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .autoupdatingCurrent
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }

    private static func visibleRange(for date: Date, mode: DisplayMode, calendar: Calendar) -> DateInterval {
        switch mode {
        case .month:
            let grid = CalendarMonthGridBuilder.buildMonth(containing: date, calendar: calendar)
            let start = grid.days.first?.date ?? calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: grid.days.count, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .week:
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 0)
            let start = calendar.startOfDay(for: weekInterval.start)
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .day:
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        }
    }
}
