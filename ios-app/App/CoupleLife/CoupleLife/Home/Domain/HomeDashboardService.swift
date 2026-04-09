import Foundation

struct HomeDashboardTaskEvent: Equatable, Hashable {
    let title: String
    let dueAt: Date?
}

struct HomeDashboardSummary: Equatable {
    let dayRange: DateInterval
    let todayTaskTotal: Int
    let todayTaskCompleted: Int
    let todayRecordTotal: Int
    let recordTypeCounts: [RecordType: Int]
    let importantEvents: [HomeDashboardTaskEvent]
    let weeklyInsight: HomeDashboardWeeklyInsight
    let steps: Int?
    let sleepHours: Double?

    var hasAnyData: Bool {
        todayTaskTotal > 0 ||
            todayRecordTotal > 0 ||
            !importantEvents.isEmpty ||
            weeklyInsight.hasAnyData ||
            steps != nil ||
            sleepHours != nil
    }
}

struct HomeDashboardWeeklyInsight: Equatable {
    let weekRange: DateInterval
    let totalTaskCount: Int
    let completedTaskCount: Int
    let recordCount: Int
    let activeDayCount: Int
    let dominantRecordType: RecordType?
    let totalSteps: Int?
    let averageSleepHours: Double?

    var hasAnyData: Bool {
        totalTaskCount > 0 ||
            recordCount > 0 ||
            activeDayCount > 0 ||
            totalSteps != nil ||
            averageSleepHours != nil
    }
}

protocol HomeDashboardService {
    func load(for day: Date, ownerUserId: String) throws -> HomeDashboardSummary
}

final class DefaultHomeDashboardService: HomeDashboardService {
    private let taskRepository: any TaskRepository
    private let recordRepository: any RecordRepository
    private let healthSnapshotRepository: any HealthSnapshotRepository
    private let calendar: Calendar

    init(
        taskRepository: any TaskRepository,
        recordRepository: any RecordRepository,
        healthSnapshotRepository: any HealthSnapshotRepository,
        calendar: Calendar = .current
    ) {
        self.taskRepository = taskRepository
        self.recordRepository = recordRepository
        self.healthSnapshotRepository = healthSnapshotRepository
        self.calendar = calendar
    }

    func load(for day: Date, ownerUserId: String) throws -> HomeDashboardSummary {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let eventWindowEnd = calendar.date(byAdding: .day, value: 7, to: dayStart) ?? dayEnd
        let weekRange = calendar.dateInterval(of: .weekOfYear, for: day)
            ?? DateInterval(start: dayStart, end: eventWindowEnd)

        let todayTasks = try taskRepository.tasks(
            scheduledFrom: dayStart,
            to: dayEnd,
            ownerUserId: ownerUserId,
            status: nil
        )

        let todayTaskCompleted = todayTasks.filter { $0.status == .done }.count

        let upcomingTasks = try taskRepository.tasks(
            scheduledFrom: dayStart,
            to: eventWindowEnd,
            ownerUserId: ownerUserId,
            status: nil
        )
            .filter { $0.status == .todo || $0.status == .postponed }

        let importantEvents = upcomingTasks
            .sorted {
                let lhs = $0.dueAt ?? $0.startAt ?? $0.updatedAt
                let rhs = $1.dueAt ?? $1.startAt ?? $1.updatedAt
                return lhs < rhs
            }
            .prefix(3)
            .map { HomeDashboardTaskEvent(title: $0.title, dueAt: $0.dueAt ?? $0.startAt) }

        let records = try recordRepository.records(from: dayStart, to: dayEnd)
        let ownerRecords = records.filter { $0.ownerUserId == ownerUserId }
        let recordTypeCounts = ownerRecords.reduce(into: [RecordType: Int]()) { partialResult, record in
            partialResult[record.type, default: 0] += 1
        }

        let healthSnapshot = try healthSnapshotRepository.snapshot(dayStart: dayStart, ownerUserId: ownerUserId)
        let steps = healthSnapshot?.steps.map { Int($0.rounded()) }
        let sleepHours = healthSnapshot?.sleepSeconds.map { ($0 / 3600).rounded(toPlaces: 1) }
        let weeklyInsight = try loadWeeklyInsight(
            weekRange: weekRange,
            ownerUserId: ownerUserId
        )

        return HomeDashboardSummary(
            dayRange: DateInterval(start: dayStart, end: dayEnd),
            todayTaskTotal: todayTasks.count,
            todayTaskCompleted: todayTaskCompleted,
            todayRecordTotal: ownerRecords.count,
            recordTypeCounts: recordTypeCounts,
            importantEvents: Array(importantEvents),
            weeklyInsight: weeklyInsight,
            steps: steps,
            sleepHours: sleepHours
        )
    }

    private func loadWeeklyInsight(weekRange: DateInterval, ownerUserId: String) throws -> HomeDashboardWeeklyInsight {
        let weeklyTasks = try taskRepository.tasks(
            scheduledFrom: weekRange.start,
            to: weekRange.end,
            ownerUserId: ownerUserId,
            status: nil
        )
        let weeklyRecords = try recordRepository.records(from: weekRange.start, to: weekRange.end)
            .filter { $0.ownerUserId == ownerUserId }
        let weeklySnapshots = try healthSnapshotRepository.snapshots(
            bucket: .day,
            from: weekRange.start,
            to: weekRange.end,
            ownerUserId: ownerUserId
        )

        let recordTypeCounts = weeklyRecords.reduce(into: [RecordType: Int]()) { partialResult, record in
            partialResult[record.type, default: 0] += 1
        }
        let dominantRecordType = recordTypeCounts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.rawValue < rhs.key.rawValue
                }
                return lhs.value > rhs.value
            }
            .first?
            .key
        let activeDayCount = Set(weeklyRecords.map { calendar.startOfDay(for: $0.startAt) }).count
        let stepValues = weeklySnapshots.compactMap(\.steps)
        let totalSteps = stepValues.isEmpty ? nil : Int(stepValues.reduce(0, +).rounded())
        let sleepValues = weeklySnapshots.compactMap(\.sleepSeconds)
        let averageSleepHours = sleepValues.isEmpty
            ? nil
            : (sleepValues.reduce(0, +) / Double(sleepValues.count) / 3600).rounded(toPlaces: 1)

        return HomeDashboardWeeklyInsight(
            weekRange: weekRange,
            totalTaskCount: weeklyTasks.count,
            completedTaskCount: weeklyTasks.filter { $0.status == .done }.count,
            recordCount: weeklyRecords.count,
            activeDayCount: activeDayCount,
            dominantRecordType: dominantRecordType,
            totalSteps: totalSteps,
            averageSleepHours: averageSleepHours
        )
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
