import XCTest
@testable import CoupleLife

@MainActor
final class PlanningViewModelTests: XCTestCase {
    func testPlanViewGroupsScheduledTasksByStartOfDayAndAppendsUnscheduledInAllRange() {
        let calendar = fixedCalendar()
        let now = makeDate(year: 2024, month: 3, day: 28, hour: 9, calendar: calendar)
        let repository = InMemoryPlanningTaskRepository(tasks: [
            makeTask(
                title: "今日开始",
                startAt: makeDate(year: 2024, month: 3, day: 28, hour: 8, calendar: calendar),
                status: .todo,
                planLevel: .day,
                updatedAt: now
            ),
            makeTask(
                title: "明日截止",
                dueAt: makeDate(year: 2024, month: 3, day: 29, hour: 10, calendar: calendar),
                status: .todo,
                planLevel: .day,
                updatedAt: now
            ),
            makeTask(
                title: "未排期",
                status: .todo,
                planLevel: .day,
                updatedAt: now
            )
        ])
        let viewModel = makeViewModel(repository: repository, calendar: calendar, now: now)

        viewModel.selectedPlanLevel = .day
        viewModel.selectedStatusFilter = .all
        viewModel.displayMode = .plan
        viewModel.dateRangeFilter = .all
        viewModel.load()

        XCTAssertEqual(viewModel.planSections.count, 3)
        XCTAssertEqual(viewModel.planSections.map(\.date), [
            calendar.startOfDay(for: makeDate(year: 2024, month: 3, day: 28, hour: 0, calendar: calendar)),
            calendar.startOfDay(for: makeDate(year: 2024, month: 3, day: 29, hour: 0, calendar: calendar)),
            nil
        ])
        XCTAssertEqual(viewModel.planSections[0].tasks.map(\.title), ["今日开始"])
        XCTAssertEqual(viewModel.planSections[1].tasks.map(\.title), ["明日截止"])
        XCTAssertEqual(viewModel.planSections[2].tasks.map(\.title), ["未排期"])
    }

    func testCustomDateRangeUsesInclusiveBoundsAndHidesUnscheduledTasks() {
        let calendar = fixedCalendar()
        let now = makeDate(year: 2024, month: 3, day: 28, hour: 9, calendar: calendar)
        let repository = InMemoryPlanningTaskRepository(tasks: [
            makeTask(
                title: "范围开始",
                dueAt: makeDate(year: 2024, month: 3, day: 28, hour: 10, calendar: calendar),
                status: .todo,
                planLevel: .day,
                updatedAt: now
            ),
            makeTask(
                title: "范围结束",
                dueAt: makeDate(year: 2024, month: 3, day: 29, hour: 10, calendar: calendar),
                status: .todo,
                planLevel: .day,
                updatedAt: now
            ),
            makeTask(
                title: "范围外",
                dueAt: makeDate(year: 2024, month: 3, day: 30, hour: 10, calendar: calendar),
                status: .todo,
                planLevel: .day,
                updatedAt: now
            ),
            makeTask(
                title: "未排期",
                status: .todo,
                planLevel: .day,
                updatedAt: now
            )
        ])
        let viewModel = makeViewModel(repository: repository, calendar: calendar, now: now)

        viewModel.selectedPlanLevel = .day
        viewModel.selectedStatusFilter = .all
        viewModel.displayMode = .plan
        viewModel.dateRangeFilter = .custom
        viewModel.customDateRangeStart = makeDate(year: 2024, month: 3, day: 28, hour: 0, calendar: calendar)
        viewModel.customDateRangeEnd = makeDate(year: 2024, month: 3, day: 29, hour: 23, calendar: calendar)
        viewModel.load()

        XCTAssertEqual(viewModel.planSections.count, 2)
        XCTAssertEqual(viewModel.planSections.map(\.tasks).flatMap { $0.map(\.title) }, ["范围开始", "范围结束"])
        XCTAssertTrue(viewModel.planSections.allSatisfy { $0.date != nil })
    }

    func testTodayRangeIncludesOnlyTodayScheduledTasks() {
        let calendar = fixedCalendar()
        let now = makeDate(year: 2024, month: 3, day: 28, hour: 9, calendar: calendar)
        let repository = InMemoryPlanningTaskRepository(tasks: [
            makeTask(
                title: "今天任务",
                dueAt: makeDate(year: 2024, month: 3, day: 28, hour: 10, calendar: calendar),
                status: .todo,
                planLevel: .day,
                updatedAt: now
            ),
            makeTask(
                title: "明天任务",
                dueAt: makeDate(year: 2024, month: 3, day: 29, hour: 10, calendar: calendar),
                status: .todo,
                planLevel: .day,
                updatedAt: now
            ),
            makeTask(
                title: "未排期",
                status: .todo,
                planLevel: .day,
                updatedAt: now
            )
        ])
        let viewModel = makeViewModel(repository: repository, calendar: calendar, now: now)

        viewModel.selectedPlanLevel = .day
        viewModel.selectedStatusFilter = .all
        viewModel.displayMode = .plan
        viewModel.dateRangeFilter = .today
        viewModel.load()

        XCTAssertEqual(viewModel.planSections.count, 1)
        XCTAssertEqual(viewModel.planSections.first?.tasks.map(\.title), ["今天任务"])
        XCTAssertEqual(viewModel.planSections.first?.date, calendar.startOfDay(for: now))
    }

    func testNext7DaysRangeExcludesDaySevenBoundaryAndHidesUnscheduledTasks() {
        let calendar = fixedCalendar()
        let now = makeDate(year: 2024, month: 3, day: 28, hour: 9, calendar: calendar)
        let todayStart = calendar.startOfDay(for: now)
        let day6Start = calendar.date(byAdding: .day, value: 6, to: todayStart)!
        let day7Start = calendar.date(byAdding: .day, value: 7, to: todayStart)!

        let repository = InMemoryPlanningTaskRepository(tasks: [
            makeTask(
                title: "今天任务",
                dueAt: calendar.date(byAdding: .hour, value: 10, to: todayStart),
                status: .todo,
                planLevel: .day,
                updatedAt: now
            ),
            makeTask(
                title: "第 6 天任务",
                dueAt: calendar.date(byAdding: .hour, value: 10, to: day6Start),
                status: .todo,
                planLevel: .day,
                updatedAt: now
            ),
            makeTask(
                title: "边界任务",
                dueAt: calendar.date(byAdding: .hour, value: 10, to: day7Start),
                status: .todo,
                planLevel: .day,
                updatedAt: now
            ),
            makeTask(
                title: "未排期",
                status: .todo,
                planLevel: .day,
                updatedAt: now
            )
        ])
        let viewModel = makeViewModel(repository: repository, calendar: calendar, now: now)

        viewModel.selectedPlanLevel = .day
        viewModel.selectedStatusFilter = .all
        viewModel.displayMode = .plan
        viewModel.dateRangeFilter = .next7Days
        viewModel.load()

        XCTAssertEqual(viewModel.planSections.count, 2)
        XCTAssertEqual(viewModel.planSections.map(\.tasks).flatMap { $0.map(\.title) }, ["今天任务", "第 6 天任务"])
        XCTAssertTrue(viewModel.planSections.allSatisfy { $0.date != nil })
    }

    func testStatusSectionsHonorDateRangeFilterInListMode() {
        let calendar = fixedCalendar()
        let now = makeDate(year: 2024, month: 3, day: 28, hour: 9, calendar: calendar)
        let repository = InMemoryPlanningTaskRepository(tasks: [
            makeTask(
                title: "今天任务",
                dueAt: makeDate(year: 2024, month: 3, day: 28, hour: 10, calendar: calendar),
                status: .todo,
                planLevel: .day,
                updatedAt: now
            ),
            makeTask(
                title: "明天任务",
                dueAt: makeDate(year: 2024, month: 3, day: 29, hour: 10, calendar: calendar),
                status: .todo,
                planLevel: .day,
                updatedAt: now
            ),
            makeTask(
                title: "未排期",
                status: .todo,
                planLevel: .day,
                updatedAt: now
            )
        ])
        let viewModel = makeViewModel(repository: repository, calendar: calendar, now: now)

        viewModel.selectedPlanLevel = .day
        viewModel.selectedStatusFilter = .all
        viewModel.displayMode = .list
        viewModel.dateRangeFilter = .today
        viewModel.load()

        XCTAssertEqual(viewModel.statusSections.count, 1)
        XCTAssertEqual(viewModel.statusSections.first?.tasks.map(\.title), ["今天任务"])
    }

    func testWeekPlanViewGroupsTasksByWeekStartAndSortsWeeksAscending() {
        let calendar = fixedCalendar()
        let now = makeDate(year: 2024, month: 3, day: 28, hour: 9, calendar: calendar)
        let repository = InMemoryPlanningTaskRepository(tasks: [
            makeTask(
                title: "本周后半段",
                dueAt: makeDate(year: 2024, month: 3, day: 28, hour: 10, calendar: calendar),
                status: .todo,
                planLevel: .week,
                updatedAt: now
            ),
            makeTask(
                title: "下一周",
                dueAt: makeDate(year: 2024, month: 4, day: 2, hour: 10, calendar: calendar),
                status: .todo,
                planLevel: .week,
                updatedAt: now
            ),
            makeTask(
                title: "本周前半段",
                dueAt: makeDate(year: 2024, month: 3, day: 26, hour: 10, calendar: calendar),
                status: .todo,
                planLevel: .week,
                updatedAt: now
            )
        ])
        let viewModel = makeViewModel(repository: repository, calendar: calendar, now: now)

        viewModel.selectedPlanLevel = .week
        viewModel.selectedStatusFilter = .all
        viewModel.displayMode = .plan
        viewModel.dateRangeFilter = .all
        viewModel.load()

        XCTAssertEqual(viewModel.planSections.map(\.title), [
            "2024-03-25 ~ 2024-03-31",
            "2024-04-01 ~ 2024-04-07"
        ])
        XCTAssertEqual(viewModel.planSections.map(\.tasks).map { $0.map(\.title) }, [
            ["本周前半段", "本周后半段"],
            ["下一周"]
        ])
        XCTAssertEqual(viewModel.planSections.map(\.date), [
            makeDate(year: 2024, month: 3, day: 25, hour: 0, calendar: calendar),
            makeDate(year: 2024, month: 4, day: 1, hour: 0, calendar: calendar)
        ])
    }

    func testMonthPlanViewGroupsTasksByMonthStartAndSortsMonthsAscending() {
        let calendar = fixedCalendar()
        let now = makeDate(year: 2024, month: 3, day: 28, hour: 9, calendar: calendar)
        let repository = InMemoryPlanningTaskRepository(tasks: [
            makeTask(
                title: "四月任务",
                dueAt: makeDate(year: 2024, month: 4, day: 2, hour: 10, calendar: calendar),
                status: .todo,
                planLevel: .month,
                updatedAt: now
            ),
            makeTask(
                title: "三月后半段",
                dueAt: makeDate(year: 2024, month: 3, day: 28, hour: 10, calendar: calendar),
                status: .todo,
                planLevel: .month,
                updatedAt: now
            ),
            makeTask(
                title: "三月前半段",
                dueAt: makeDate(year: 2024, month: 3, day: 5, hour: 10, calendar: calendar),
                status: .todo,
                planLevel: .month,
                updatedAt: now
            )
        ])
        let viewModel = makeViewModel(repository: repository, calendar: calendar, now: now)

        viewModel.selectedPlanLevel = .month
        viewModel.selectedStatusFilter = .all
        viewModel.displayMode = .plan
        viewModel.dateRangeFilter = .all
        viewModel.load()

        XCTAssertEqual(viewModel.planSections.map(\.title), [
            "2024年3月",
            "2024年4月"
        ])
        XCTAssertEqual(viewModel.planSections.map(\.tasks).map { $0.map(\.title) }, [
            ["三月前半段", "三月后半段"],
            ["四月任务"]
        ])
        XCTAssertEqual(viewModel.planSections.map(\.date), [
            makeDate(year: 2024, month: 3, day: 1, hour: 0, calendar: calendar),
            makeDate(year: 2024, month: 4, day: 1, hour: 0, calendar: calendar)
        ])
    }

    func testYearPlanViewGroupsTasksByYearStartAndSortsYearsAscending() {
        let calendar = fixedCalendar()
        let now = makeDate(year: 2024, month: 3, day: 28, hour: 9, calendar: calendar)
        let repository = InMemoryPlanningTaskRepository(tasks: [
            makeTask(
                title: "2025任务",
                dueAt: makeDate(year: 2025, month: 1, day: 3, hour: 10, calendar: calendar),
                status: .todo,
                planLevel: .year,
                updatedAt: now
            ),
            makeTask(
                title: "2024任务",
                dueAt: makeDate(year: 2024, month: 12, day: 31, hour: 10, calendar: calendar),
                status: .todo,
                planLevel: .year,
                updatedAt: now
            )
        ])
        let viewModel = makeViewModel(repository: repository, calendar: calendar, now: now)

        viewModel.selectedPlanLevel = .year
        viewModel.selectedStatusFilter = .all
        viewModel.displayMode = .plan
        viewModel.dateRangeFilter = .all
        viewModel.load()

        XCTAssertEqual(viewModel.planSections.map(\.title), [
            "2024年",
            "2025年"
        ])
        XCTAssertEqual(viewModel.planSections.map(\.tasks).map { $0.map(\.title) }, [
            ["2024任务"],
            ["2025任务"]
        ])
        XCTAssertEqual(viewModel.planSections.map(\.date), [
            makeDate(year: 2024, month: 1, day: 1, hour: 0, calendar: calendar),
            makeDate(year: 2025, month: 1, day: 1, hour: 0, calendar: calendar)
        ])
    }

    func testSwitchingViewModesDoesNotResetFilters() {
        let calendar = fixedCalendar()
        let now = makeDate(year: 2024, month: 3, day: 28, hour: 9, calendar: calendar)
        let repository = InMemoryPlanningTaskRepository(tasks: [])
        let viewModel = makeViewModel(repository: repository, calendar: calendar, now: now)

        viewModel.selectedPlanLevel = .week
        viewModel.selectedStatusFilter = .done
        viewModel.dateRangeFilter = .custom
        viewModel.customDateRangeStart = makeDate(year: 2024, month: 3, day: 20, hour: 0, calendar: calendar)
        viewModel.customDateRangeEnd = makeDate(year: 2024, month: 3, day: 24, hour: 23, calendar: calendar)
        viewModel.displayMode = .plan
        viewModel.displayMode = .list

        XCTAssertEqual(viewModel.selectedPlanLevel, .week)
        XCTAssertEqual(viewModel.selectedStatusFilter, .done)
        XCTAssertEqual(viewModel.dateRangeFilter, .custom)
        XCTAssertEqual(viewModel.customDateRangeStart, makeDate(year: 2024, month: 3, day: 20, hour: 0, calendar: calendar))
        XCTAssertEqual(viewModel.customDateRangeEnd, makeDate(year: 2024, month: 3, day: 24, hour: 23, calendar: calendar))
    }

    private func makeViewModel(
        repository: InMemoryPlanningTaskRepository,
        calendar: Calendar,
        now: Date
    ) -> PlanningViewModel {
        let calendarSyncService = TestCalendarSyncService()
        let calendarSyncSettings = TestCalendarSyncSettingsStore(isEnabled: false)
        let service = DefaultPlanningTaskService(
            taskRepository: repository,
            ownerUserId: "local",
            calendar: calendar,
            calendarSyncService: calendarSyncService,
            calendarSyncSettings: calendarSyncSettings,
            nowProvider: { now }
        )
        return PlanningViewModel(
            service: service,
            calendarSyncController: DefaultCalendarSyncSettingsController(
                calendarSyncService: calendarSyncService,
                settingsStore: calendarSyncSettings
            ),
            calendar: calendar,
            nowProvider: { now }
        )
    }

    private func makeTask(
        title: String,
        detail: String? = nil,
        startAt: Date? = nil,
        dueAt: Date? = nil,
        status: TaskStatus,
        planLevel: PlanLevel,
        updatedAt: Date
    ) -> TaskItem {
        TaskItem(
            title: title,
            detail: detail,
            startAt: startAt,
            dueAt: dueAt,
            status: status,
            planLevel: planLevel,
            ownerUserId: "local",
            createdAt: updatedAt,
            updatedAt: updatedAt
        )
    }

    private func fixedCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, calendar: Calendar) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day,
            hour: hour
        )
        return components.date!
    }
}

private final class InMemoryPlanningTaskRepository: TaskRepository {
    private let tasksValue: [TaskItem]

    init(tasks: [TaskItem]) {
        self.tasksValue = tasks
    }

    func create(_ task: TaskItem) throws {}

    func update(_ task: TaskItem) throws {}

    func delete(_ task: TaskItem) throws {}

    func tasks(status: TaskStatus?) throws -> [TaskItem] {
        guard let status else {
            return tasksValue
        }
        return tasksValue.filter { $0.status == status }
    }

    func tasks(scheduledFrom start: Date, to end: Date, ownerUserId: String, status: TaskStatus?) throws -> [TaskItem] {
        tasksValue
            .filter { $0.ownerUserId == ownerUserId }
            .filter { task in
                guard let status else { return true }
                return task.status == status
            }
            .filter { task in
                let targetDate = task.dueAt ?? task.startAt
                guard let targetDate else { return false }
                return targetDate >= start && targetDate < end
            }
    }
}
