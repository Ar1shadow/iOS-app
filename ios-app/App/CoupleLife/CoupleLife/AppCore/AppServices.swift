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
