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
    let steps: Int?
    let sleepHours: Double?

    var hasAnyData: Bool {
        todayTaskTotal > 0 ||
            todayRecordTotal > 0 ||
            !importantEvents.isEmpty ||
            steps != nil ||
            sleepHours != nil
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

        return HomeDashboardSummary(
            dayRange: DateInterval(start: dayStart, end: dayEnd),
            todayTaskTotal: todayTasks.count,
            todayTaskCompleted: todayTaskCompleted,
            todayRecordTotal: ownerRecords.count,
            recordTypeCounts: recordTypeCounts,
            importantEvents: Array(importantEvents),
            steps: steps,
            sleepHours: sleepHours
        )
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
