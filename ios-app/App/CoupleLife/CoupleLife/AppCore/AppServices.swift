import Foundation

enum ServiceAvailability: Equatable {
    case available
    case notAuthorized
    case notSupported
    case failed(String)
}

protocol CalendarSyncService {
    func availability() async -> ServiceAvailability
}

protocol HealthDataService {
    func availability() async -> ServiceAvailability
}

protocol NotificationScheduler {
    func availability() async -> ServiceAvailability
}

protocol CloudSyncService {
    func availability() async -> ServiceAvailability
}

struct NoopCalendarSyncService: CalendarSyncService {
    func availability() async -> ServiceAvailability { .notSupported }
}

struct NoopHealthDataService: HealthDataService {
    func availability() async -> ServiceAvailability { .notSupported }
}

struct NoopNotificationScheduler: NotificationScheduler {
    func availability() async -> ServiceAvailability { .notSupported }
}

struct NoopCloudSyncService: CloudSyncService {
    func availability() async -> ServiceAvailability { .notSupported }
}

