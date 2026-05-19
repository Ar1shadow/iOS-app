import Foundation

#if canImport(CloudKit)
import CloudKit
#endif

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
    func requestAuthorization() async -> ServiceAvailability
    func scheduleTaskReminder(_ reminder: TaskReminderPayload) async
    func cancelTaskReminder(id: UUID) async
    func cancelAllTaskReminders() async
    func scheduleWaterReminder() async
    func cancelWaterReminder() async
}

enum TaskReminderKind: Equatable {
    case personalTask
}

struct TaskReminderPayload: Equatable {
    let id: UUID
    let title: String
    let fireDate: Date
    let kind: TaskReminderKind
}

struct NotificationSettingsStatus: Equatable {
    var isTaskRemindersEnabled: Bool
    var isWaterReminderEnabled: Bool
    var availability: ServiceAvailability
}

protocol NotificationSettingsStore: AnyObject {
    var isTaskRemindersEnabled: Bool { get set }
    var isWaterReminderEnabled: Bool { get set }
}

protocol ActiveCoupleSpaceStore: AnyObject {
    var activeCoupleSpaceId: String? { get set }
}

protocol NotificationSettingsControlling {
    func currentStatus() async -> NotificationSettingsStatus
    func setTaskRemindersEnabled(_ enabled: Bool) async -> NotificationSettingsStatus
    func setWaterReminderEnabled(_ enabled: Bool) async -> NotificationSettingsStatus
}

protocol CloudSyncService {
    func availability() async -> ServiceAvailability
    func currentStatus() async -> CloudSyncStatus
    func refresh() async -> CloudSyncStatus
}

enum CloudShareAcceptanceState: Equatable {
    case idle
    case processing
    case accepted
    case failed
}

struct CloudShareAcceptanceStatus: Equatable {
    var availability: ServiceAvailability
    var state: CloudShareAcceptanceState
    var lastURL: URL?
    var lastErrorCode: String?
    var lastUpdatedAt: Date?

    static let unsupported = CloudShareAcceptanceStatus(
        availability: .notSupported,
        state: .idle,
        lastURL: nil,
        lastErrorCode: nil,
        lastUpdatedAt: nil
    )
}

protocol CloudShareAcceptanceService {
    func currentStatus() async -> CloudShareAcceptanceStatus
    func acceptShare(from url: URL) async -> CloudShareAcceptanceStatus

    #if canImport(CloudKit)
    func acceptShare(from metadata: CKShare.Metadata) async -> CloudShareAcceptanceStatus
    #endif
}

enum CloudShareInvitationState: Equatable {
    case idle
    case creating
    case active
    case revoking
    case revoked
    case failed
}

struct CloudShareInvitationStatus: Equatable {
    var availability: ServiceAvailability
    var state: CloudShareInvitationState
    var lastShareURL: URL?
    var participantCount: Int
    var lastErrorCode: String?
    var lastUpdatedAt: Date?

    static let unsupported = CloudShareInvitationStatus(
        availability: .notSupported,
        state: .idle,
        lastShareURL: nil,
        participantCount: 0,
        lastErrorCode: nil,
        lastUpdatedAt: nil
    )
}

protocol CloudShareInvitationService {
    func currentStatus() async -> CloudShareInvitationStatus
    func createShare() async -> CloudShareInvitationStatus
    func revokeShare() async -> CloudShareInvitationStatus
    func reinvite() async -> CloudShareInvitationStatus
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
    func requestAuthorization() async -> ServiceAvailability { .notSupported }
    func scheduleTaskReminder(_ reminder: TaskReminderPayload) async {}
    func cancelTaskReminder(id: UUID) async {}
    func cancelAllTaskReminders() async {}
    func scheduleWaterReminder() async {}
    func cancelWaterReminder() async {}
}

struct NoopCloudSyncService: CloudSyncService {
    func availability() async -> ServiceAvailability { .notSupported }
    func currentStatus() async -> CloudSyncStatus { .unsupported }
    func refresh() async -> CloudSyncStatus { .unsupported }
}

struct NoopCloudShareAcceptanceService: CloudShareAcceptanceService {
    func currentStatus() async -> CloudShareAcceptanceStatus { .unsupported }
    func acceptShare(from url: URL) async -> CloudShareAcceptanceStatus {
        CloudShareAcceptanceStatus(
            availability: .notSupported,
            state: .failed,
            lastURL: url,
            lastErrorCode: "not_supported",
            lastUpdatedAt: Date()
        )
    }

    #if canImport(CloudKit)
    func acceptShare(from metadata: CKShare.Metadata) async -> CloudShareAcceptanceStatus {
        CloudShareAcceptanceStatus(
            availability: .notSupported,
            state: .failed,
            lastURL: metadata.share.url,
            lastErrorCode: "not_supported",
            lastUpdatedAt: Date()
        )
    }
    #endif
}

struct NoopCloudShareInvitationService: CloudShareInvitationService {
    func currentStatus() async -> CloudShareInvitationStatus { .unsupported }
    func createShare() async -> CloudShareInvitationStatus {
        CloudShareInvitationStatus(
            availability: .notSupported,
            state: .failed,
            lastShareURL: nil,
            participantCount: 0,
            lastErrorCode: "not_supported",
            lastUpdatedAt: Date()
        )
    }
    func revokeShare() async -> CloudShareInvitationStatus {
        CloudShareInvitationStatus(
            availability: .notSupported,
            state: .failed,
            lastShareURL: nil,
            participantCount: 0,
            lastErrorCode: "not_supported",
            lastUpdatedAt: Date()
        )
    }
    func reinvite() async -> CloudShareInvitationStatus {
        CloudShareInvitationStatus(
            availability: .notSupported,
            state: .failed,
            lastShareURL: nil,
            participantCount: 0,
            lastErrorCode: "not_supported",
            lastUpdatedAt: Date()
        )
    }
}
