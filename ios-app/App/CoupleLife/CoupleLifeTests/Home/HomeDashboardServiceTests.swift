import XCTest
@testable import CoupleLife

final class HomeDashboardServiceTests: XCTestCase {
    func testBuildsTodaySummaryFromRepositories() throws {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let weekRange = calendar.dateInterval(of: .weekOfYear, for: day)!

        let due = calendar.date(byAdding: .hour, value: 10, to: dayStart)!
        let tomorrowDue = calendar.date(byAdding: .day, value: 1, to: due)!
        let nextWeekDue = calendar.date(byAdding: .day, value: 6, to: due)!
        let beyondWindowDue = calendar.date(byAdding: .day, value: 8, to: due)!
        let oldDue = calendar.date(byAdding: .day, value: -1, to: dayStart)!

        let tasks: [TaskItem] = [
            TaskItem(title: "买菜", dueAt: due, status: .todo, ownerUserId: "u1"),
            TaskItem(title: "倒垃圾", dueAt: due, status: .done, ownerUserId: "u1"),
            TaskItem(title: "明天复诊", dueAt: tomorrowDue, status: .postponed, ownerUserId: "u1"),
            TaskItem(title: "周末体检", dueAt: nextWeekDue, status: .todo, ownerUserId: "u1"),
            TaskItem(title: "窗口外任务", dueAt: beyondWindowDue, status: .todo, ownerUserId: "u1"),
            TaskItem(title: "旧任务", dueAt: oldDue, status: .todo, ownerUserId: "u1"),
            TaskItem(title: "他人任务", dueAt: due, status: .todo, ownerUserId: "u2")
        ]

        let records: [Record] = [
            Record(type: .water, startAt: calendar.date(byAdding: .hour, value: 8, to: dayStart)!, ownerUserId: "u1"),
            Record(type: .water, startAt: calendar.date(byAdding: .hour, value: 11, to: dayStart)!, ownerUserId: "u1"),
            Record(type: .sleep, startAt: calendar.date(byAdding: .hour, value: 2, to: dayStart)!, ownerUserId: "u1"),
            Record(type: .activity, startAt: calendar.date(byAdding: .hour, value: 9, to: dayStart)!, ownerUserId: "u2")
        ]

        let snapshot = HealthMetricSnapshot(dayStart: dayStart, ownerUserId: "u1", steps: 6200, sleepSeconds: 7.5 * 3600)

        let service = DefaultHomeDashboardService(
            taskRepository: InMemoryTaskRepository(tasks: tasks),
            recordRepository: InMemoryRecordRepository(records: records),
            healthSnapshotRepository: InMemoryHealthSnapshotRepository(snapshot: snapshot),
            calendar: calendar
        )

        let dashboard = try service.load(for: day, ownerUserId: "u1")

        XCTAssertEqual(dashboard.todayTaskTotal, 2)
        XCTAssertEqual(dashboard.todayTaskCompleted, 1)
        XCTAssertEqual(dashboard.todayRecordTotal, 3)
        XCTAssertEqual(dashboard.recordTypeCounts[.water], 2)
        XCTAssertEqual(dashboard.recordTypeCounts[.sleep], 1)
        XCTAssertEqual(dashboard.importantEvents.map(\.title), ["买菜", "明天复诊", "周末体检"])
        XCTAssertEqual(dashboard.steps, 6200)
        XCTAssertEqual(dashboard.sleepHours, 7.5)
        XCTAssertEqual(dashboard.dayRange.start, dayStart)
        XCTAssertEqual(dashboard.dayRange.end, dayEnd)
        XCTAssertEqual(dashboard.weeklyInsight.weekRange, weekRange)
        XCTAssertEqual(dashboard.weeklyInsight.totalTaskCount, 4)
        XCTAssertEqual(dashboard.weeklyInsight.completedTaskCount, 1)
        XCTAssertEqual(dashboard.weeklyInsight.recordCount, 3)
        XCTAssertEqual(dashboard.weeklyInsight.activeDayCount, 1)
        XCTAssertEqual(dashboard.weeklyInsight.dominantRecordType, .water)
        XCTAssertEqual(dashboard.weeklyInsight.totalSteps, 6200)
        XCTAssertEqual(dashboard.weeklyInsight.averageSleepHours, 7.5)
    }

    func testReturnsEmptySummaryWhenNoData() throws {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let service = DefaultHomeDashboardService(
            taskRepository: InMemoryTaskRepository(tasks: []),
            recordRepository: InMemoryRecordRepository(records: []),
            healthSnapshotRepository: InMemoryHealthSnapshotRepository(snapshot: nil)
        )

        let dashboard = try service.load(for: day, ownerUserId: "u1")

        XCTAssertEqual(dashboard.todayTaskTotal, 0)
        XCTAssertEqual(dashboard.todayTaskCompleted, 0)
        XCTAssertEqual(dashboard.todayRecordTotal, 0)
        XCTAssertTrue(dashboard.recordTypeCounts.isEmpty)
        XCTAssertTrue(dashboard.importantEvents.isEmpty)
        XCTAssertNil(dashboard.steps)
        XCTAssertNil(dashboard.sleepHours)
        XCTAssertFalse(dashboard.hasAnyData)
    }

    func testBuildsWeeklyInsightAcrossTasksRecordsAndHealthSnapshots() throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let weekRange = calendar.dateInterval(of: .weekOfYear, for: day)!
        let weekDayOne = calendar.date(byAdding: .hour, value: 12, to: weekRange.start)!
        let weekDayTwo = calendar.date(byAdding: .day, value: 2, to: weekDayOne)!
        let outsideWeek = calendar.date(byAdding: .day, value: 7, to: weekRange.start)!

        let service = DefaultHomeDashboardService(
            taskRepository: InMemoryTaskRepository(tasks: [
                TaskItem(title: "本周完成", dueAt: weekDayOne, status: .done, ownerUserId: "u1"),
                TaskItem(title: "本周待办", dueAt: weekDayTwo, status: .todo, ownerUserId: "u1"),
                TaskItem(title: "他人待办", dueAt: weekDayTwo, status: .todo, ownerUserId: "u2"),
                TaskItem(title: "下周任务", dueAt: outsideWeek, status: .todo, ownerUserId: "u1")
            ]),
            recordRepository: InMemoryRecordRepository(records: [
                Record(type: .sleep, startAt: weekDayOne, ownerUserId: "u1"),
                Record(type: .water, startAt: weekDayOne, ownerUserId: "u1"),
                Record(type: .water, startAt: weekDayTwo, ownerUserId: "u1"),
                Record(type: .activity, startAt: weekDayTwo, ownerUserId: "u2"),
                Record(type: .custom, startAt: outsideWeek, ownerUserId: "u1")
            ]),
            healthSnapshotRepository: InMemoryHealthSnapshotRepository(snapshots: [
                HealthMetricSnapshot(dayStart: calendar.startOfDay(for: weekDayOne), ownerUserId: "u1", steps: 4200, sleepSeconds: 7 * 3600),
                HealthMetricSnapshot(dayStart: calendar.startOfDay(for: weekDayTwo), ownerUserId: "u1", steps: 6100, sleepSeconds: 8 * 3600),
                HealthMetricSnapshot(dayStart: calendar.startOfDay(for: weekDayTwo), ownerUserId: "u2", steps: 9000, sleepSeconds: 9 * 3600)
            ]),
            calendar: calendar
        )

        let dashboard = try service.load(for: day, ownerUserId: "u1")

        XCTAssertEqual(dashboard.weeklyInsight.weekRange, weekRange)
        XCTAssertEqual(dashboard.weeklyInsight.totalTaskCount, 2)
        XCTAssertEqual(dashboard.weeklyInsight.completedTaskCount, 1)
        XCTAssertEqual(dashboard.weeklyInsight.recordCount, 3)
        XCTAssertEqual(dashboard.weeklyInsight.activeDayCount, 2)
        XCTAssertEqual(dashboard.weeklyInsight.dominantRecordType, .water)
        XCTAssertEqual(dashboard.weeklyInsight.totalSteps, 10300)
        XCTAssertEqual(dashboard.weeklyInsight.averageSleepHours, 7.5)
        XCTAssertTrue(dashboard.weeklyInsight.hasAnyData)
        XCTAssertTrue(dashboard.hasAnyData)
    }

    func testHasAnyDataIncludesImportantEvents() throws {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let dayStart = calendar.startOfDay(for: day)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        let service = DefaultHomeDashboardService(
            taskRepository: InMemoryTaskRepository(tasks: [
                TaskItem(title: "明天任务", dueAt: tomorrow, status: .todo, ownerUserId: "u1")
            ]),
            recordRepository: InMemoryRecordRepository(records: []),
            healthSnapshotRepository: InMemoryHealthSnapshotRepository(snapshot: nil),
            calendar: calendar
        )

        let dashboard = try service.load(for: day, ownerUserId: "u1")

        XCTAssertEqual(dashboard.todayTaskTotal, 0)
        XCTAssertEqual(dashboard.todayRecordTotal, 0)
        XCTAssertEqual(dashboard.importantEvents.map(\.title), ["明天任务"])
        XCTAssertTrue(dashboard.hasAnyData)
    }

    func testFiltersTasksAndRecordsByOwnerUserId() throws {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let dayStart = calendar.startOfDay(for: day)
        let due = calendar.date(byAdding: .hour, value: 10, to: dayStart)!

        let service = DefaultHomeDashboardService(
            taskRepository: InMemoryTaskRepository(tasks: [
                TaskItem(title: "我的任务", dueAt: due, status: .todo, ownerUserId: "local"),
                TaskItem(title: "他人任务", dueAt: due, status: .todo, ownerUserId: "other")
            ]),
            recordRepository: InMemoryRecordRepository(records: [
                Record(type: .water, startAt: due, ownerUserId: "local"),
                Record(type: .sleep, startAt: due, ownerUserId: "other")
            ]),
            healthSnapshotRepository: InMemoryHealthSnapshotRepository(
                snapshot: HealthMetricSnapshot(dayStart: dayStart, ownerUserId: "local", steps: 1000, sleepSeconds: 3600)
            ),
            calendar: calendar
        )

        let dashboard = try service.load(for: day, ownerUserId: "local")

        XCTAssertEqual(dashboard.todayTaskTotal, 1)
        XCTAssertEqual(dashboard.todayRecordTotal, 1)
        XCTAssertEqual(dashboard.importantEvents.map(\.title), ["我的任务"])
    }

    func testIncludesPostponedTasksInImportantEvents() throws {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let dayStart = calendar.startOfDay(for: day)
        let postponedDue = calendar.date(byAdding: .day, value: 2, to: dayStart)!

        let service = DefaultHomeDashboardService(
            taskRepository: InMemoryTaskRepository(tasks: [
                TaskItem(title: "已延期复诊", dueAt: postponedDue, status: .postponed, ownerUserId: "local")
            ]),
            recordRepository: InMemoryRecordRepository(records: []),
            healthSnapshotRepository: InMemoryHealthSnapshotRepository(snapshot: nil),
            calendar: calendar
        )

        let dashboard = try service.load(for: day, ownerUserId: "local")

        XCTAssertEqual(dashboard.importantEvents.map(\.title), ["已延期复诊"])
        XCTAssertTrue(dashboard.hasAnyData)
    }
}

private final class InMemoryTaskRepository: TaskRepository {
    private let items: [TaskItem]

    init(tasks: [TaskItem]) {
        self.items = tasks
    }

    func create(_ task: TaskItem) throws {}
    func update(_ task: TaskItem) throws {}
    func delete(_ task: TaskItem) throws {}
    func tasks(status: TaskStatus?) throws -> [TaskItem] {
        guard let status else { return items }
        return items.filter { $0.status == status }
    }

    func tasks(scheduledFrom start: Date, to end: Date, ownerUserId: String, status: TaskStatus?) throws -> [TaskItem] {
        items
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

private final class InMemoryRecordRepository: RecordRepository {
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

private final class InMemoryHealthSnapshotRepository: HealthSnapshotRepository {
    private let values: [HealthMetricSnapshot]

    init(snapshot: HealthMetricSnapshot?) {
        self.values = snapshot.map { [$0] } ?? []
    }

    init(snapshots: [HealthMetricSnapshot]) {
        self.values = snapshots
    }

    func upsert(_ snapshot: HealthMetricSnapshot) throws {}
    func snapshot(bucket: HealthMetricBucket, start: Date, ownerUserId: String) throws -> HealthMetricSnapshot? {
        values.first { value in
            value.bucket == bucket && value.dayStart == start && value.ownerUserId == ownerUserId
        }
    }

    func snapshot(dayStart: Date, ownerUserId: String) throws -> HealthMetricSnapshot? {
        try snapshot(bucket: .day, start: dayStart, ownerUserId: ownerUserId)
    }

    func snapshots(bucket: HealthMetricBucket, from startDate: Date, to endDate: Date, ownerUserId: String) throws -> [HealthMetricSnapshot] {
        values.filter { value in
            value.bucket == bucket &&
                value.ownerUserId == ownerUserId &&
                value.dayStart >= startDate &&
                value.dayStart < endDate
        }
    }
}
