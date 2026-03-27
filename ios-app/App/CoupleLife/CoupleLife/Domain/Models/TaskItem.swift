import Foundation
import SwiftData

@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID

    var title: String
    var detail: String?

    var startAt: Date?
    var dueAt: Date?
    var isAllDay: Bool

    var priority: Int
    var statusRaw: String
    var planLevelRaw: String

    var ownerUserId: String
    var coupleSpaceId: String?
    var visibilityRaw: String
    var sourceRaw: String

    var systemCalendarEventId: String?

    var createdAt: Date
    var updatedAt: Date
    var version: Int

    init(
        id: UUID = UUID(),
        title: String,
        detail: String? = nil,
        startAt: Date? = nil,
        dueAt: Date? = nil,
        isAllDay: Bool = false,
        priority: Int = 0,
        status: TaskStatus = .todo,
        planLevel: PlanLevel = .day,
        ownerUserId: String,
        coupleSpaceId: String? = nil,
        visibility: Visibility = .private,
        source: DataSource = .manual,
        systemCalendarEventId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.startAt = startAt
        self.dueAt = dueAt
        self.isAllDay = isAllDay
        self.priority = priority
        self.statusRaw = status.rawValue
        self.planLevelRaw = planLevel.rawValue
        self.ownerUserId = ownerUserId
        self.coupleSpaceId = coupleSpaceId
        self.visibilityRaw = visibility.rawValue
        self.sourceRaw = source.rawValue
        self.systemCalendarEventId = systemCalendarEventId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
    }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .todo }
        set { statusRaw = newValue.rawValue }
    }

    var planLevel: PlanLevel {
        get { PlanLevel(rawValue: planLevelRaw) ?? .day }
        set { planLevelRaw = newValue.rawValue }
    }

    var visibility: Visibility {
        get { Visibility(rawValue: visibilityRaw) ?? .private }
        set { visibilityRaw = newValue.rawValue }
    }

    var source: DataSource {
        get { DataSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
}

