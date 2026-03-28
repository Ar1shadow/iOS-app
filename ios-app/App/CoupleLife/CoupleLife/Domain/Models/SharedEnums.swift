import Foundation

enum Visibility: String, Codable, CaseIterable {
    case `private`
    case coupleShared
}

enum DataSource: String, Codable, CaseIterable {
    case manual
    case systemCalendar
    case healthKit
}

enum HealthMetricBucket: String, Codable, CaseIterable {
    case day
    case week
    case month
}

enum RecordType: String, Codable, CaseIterable {
    case water
    case bowelMovement
    case menstruation
    case sleep
    case activity
    case custom
}

enum TaskStatus: String, Codable, CaseIterable {
    case todo = "todo"
    case done = "done"
    case postponed = "postponed"
    case cancelled = "cancelled"
}

enum PlanLevel: String, Codable, CaseIterable {
    case day
    case week
    case month
    case year
}
