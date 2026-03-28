import Foundation

enum ServiceAvailability: Equatable {
    case available
    case notAuthorized
    case notSupported
    case failed(String)
}

enum CalendarSyncError: LocalizedError, Equatable {
    case unavailable(ServiceAvailability)
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(.notAuthorized):
            return "系统日历权限未授权。"
        case .unavailable(.notSupported):
            return "当前环境不支持系统日历同步。"
        case .unavailable(.failed(let message)):
            return message
        case .unavailable(.available):
            return "系统日历当前不可用。"
        case .operationFailed(let message):
            return message
        }
    }
}

protocol CalendarSyncSettingsStore: AnyObject {
    var isEnabled: Bool { get set }
}

struct CalendarSyncStatus: Equatable {
    var isEnabled: Bool
    var availability: ServiceAvailability
}

protocol CalendarSyncSettingsControlling {
    func currentStatus() async -> CalendarSyncStatus
    func setSyncEnabled(_ enabled: Bool) async -> CalendarSyncStatus
}

protocol CalendarSyncService {
    func availability() async -> ServiceAvailability
    func currentAvailability() -> ServiceAvailability
    func requestAccess() async -> ServiceAvailability
    func upsertEvent(for task: TaskItem) throws -> String
    func deleteEvent(withIdentifier identifier: String) throws
}

protocol HealthDataService {
    func availability() async -> ServiceAvailability
    func requestAuthorization() async -> ServiceAvailability
    func refreshTodaySnapshot(ownerUserId: String, asOf date: Date, force: Bool) async -> ServiceAvailability
}

extension HealthDataService {
    func refreshTodaySnapshot(
        ownerUserId: String,
        asOf date: Date = Date(),
        force: Bool = false
    ) async -> ServiceAvailability {
        await refreshTodaySnapshot(ownerUserId: ownerUserId, asOf: date, force: force)
    }
}

protocol NotificationScheduler {
    func availability() async -> ServiceAvailability
}

protocol CloudSyncService {
    func availability() async -> ServiceAvailability
}

struct NoopCalendarSyncService: CalendarSyncService {
    func availability() async -> ServiceAvailability { .notSupported }
    func currentAvailability() -> ServiceAvailability { .notSupported }
    func requestAccess() async -> ServiceAvailability { .notSupported }
    func upsertEvent(for task: TaskItem) throws -> String {
        throw CalendarSyncError.unavailable(.notSupported)
    }
    func deleteEvent(withIdentifier identifier: String) throws {
        throw CalendarSyncError.unavailable(.notSupported)
    }
}

struct NoopHealthDataService: HealthDataService {
    func availability() async -> ServiceAvailability { .notSupported }
    func requestAuthorization() async -> ServiceAvailability { .notSupported }
    func refreshTodaySnapshot(ownerUserId: String, asOf date: Date, force: Bool) async -> ServiceAvailability { .notSupported }
}

struct NoopNotificationScheduler: NotificationScheduler {
    func availability() async -> ServiceAvailability { .notSupported }
}

struct NoopCloudSyncService: CloudSyncService {
    func availability() async -> ServiceAvailability { .notSupported }
}
