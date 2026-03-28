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
        let service = DefaultPlanningTaskService(
            taskRepository: repository,
            ownerUserId: "local",
            calendar: calendar,
            nowProvider: { now }
        )
        return PlanningViewModel(service: service, calendar: calendar, nowProvider: { now })
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
