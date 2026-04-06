import Foundation
import UserNotifications

enum NotificationAuthorizationStatus: Equatable {
    case authorized
    case provisional
    case ephemeral
    case denied
    case notDetermined
    case unsupported
}

struct NotificationAuthorizationOptions: OptionSet, Equatable {
    let rawValue: Int

    static let alert = NotificationAuthorizationOptions(rawValue: 1 << 0)
    static let badge = NotificationAuthorizationOptions(rawValue: 1 << 1)
    static let sound = NotificationAuthorizationOptions(rawValue: 1 << 2)
}

struct NotificationRequestDescriptor: Equatable {
    let identifier: String
    let title: String
    let body: String
    let dateComponents: DateComponents
    let repeats: Bool
}

protocol UserNotificationCenterClient {
    func getAuthorizationStatus() async -> NotificationAuthorizationStatus
    func requestAuthorization(options: NotificationAuthorizationOptions) async throws -> Bool
    func add(_ request: NotificationRequestDescriptor) async throws
    func pendingNotificationRequests() async -> [NotificationRequestDescriptor]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
}

struct SystemUserNotificationCenterClient: UserNotificationCenterClient {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func getAuthorizationStatus() async -> NotificationAuthorizationStatus {
        let settings = await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }

        switch settings.authorizationStatus {
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .ephemeral:
            return .ephemeral
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .unsupported
        }
    }

    func requestAuthorization(options: NotificationAuthorizationOptions) async throws -> Bool {
        let resolvedOptions = makeUNAuthorizationOptions(from: options)
        return try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(options: resolvedOptions) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func add(_ request: NotificationRequestDescriptor) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: request.dateComponents,
            repeats: request.repeats
        )
        let notificationRequest = UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: trigger
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(notificationRequest) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func pendingNotificationRequests() async -> [NotificationRequestDescriptor] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.compactMap(Self.makeDescriptor(from:)))
            }
        }
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func makeUNAuthorizationOptions(from options: NotificationAuthorizationOptions) -> UNAuthorizationOptions {
        var resolved: UNAuthorizationOptions = []
        if options.contains(.alert) {
            resolved.insert(.alert)
        }
        if options.contains(.badge) {
            resolved.insert(.badge)
        }
        if options.contains(.sound) {
            resolved.insert(.sound)
        }
        return resolved
    }

    private static func makeDescriptor(from request: UNNotificationRequest) -> NotificationRequestDescriptor? {
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger else {
            return nil
        }

        return NotificationRequestDescriptor(
            identifier: request.identifier,
            title: request.content.title,
            body: request.content.body,
            dateComponents: trigger.dateComponents,
            repeats: trigger.repeats
        )
    }
}

final class UserNotificationScheduler: NotificationScheduler {
    private let notificationCenter: any UserNotificationCenterClient
    private let calendar: Calendar
    private let nowProvider: () -> Date

    static let waterReminderIdentifier = "habit-reminder-water"

    init(
        notificationCenter: any UserNotificationCenterClient = SystemUserNotificationCenterClient(),
        calendar: Calendar = .current,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.notificationCenter = notificationCenter
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    func availability() async -> ServiceAvailability {
        mapAvailability(from: await notificationCenter.getAuthorizationStatus())
    }

    func requestAuthorization() async -> ServiceAvailability {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else {
                return .notAuthorized
            }
            return await availability()
        } catch {
            return .failed("通知权限请求失败，请稍后重试。")
        }
    }

    func scheduleTaskReminder(_ reminder: TaskReminderPayload) async {
        let identifier = Self.taskReminderIdentifier(for: reminder.id)
        clearNotification(withIdentifier: identifier)

        guard reminder.fireDate > nowProvider() else { return }

        let request = NotificationRequestDescriptor(
            identifier: identifier,
            title: reminder.title,
            body: reminderBody(for: reminder.kind),
            dateComponents: calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: reminder.fireDate
            ),
            repeats: false
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            // Local notifications are best-effort in MVP.
        }
    }

    func cancelTaskReminder(id: UUID) async {
        clearNotification(withIdentifier: Self.taskReminderIdentifier(for: id))
    }

    func cancelAllTaskReminders() async {
        let identifiers = await notificationCenter.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.taskReminderPrefix) }

        guard !identifiers.isEmpty else { return }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func scheduleWaterReminder() async {
        clearNotification(withIdentifier: Self.waterReminderIdentifier)

        let request = NotificationRequestDescriptor(
            identifier: Self.waterReminderIdentifier,
            title: "喝水提醒",
            body: "喝一杯水，顺手活动一下。",
            dateComponents: DateComponents(hour: 10, minute: 0),
            repeats: true
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            // Local notifications are best-effort in MVP.
        }
    }

    func cancelWaterReminder() async {
        clearNotification(withIdentifier: Self.waterReminderIdentifier)
    }

    static func taskReminderIdentifier(for taskID: UUID) -> String {
        "\(taskReminderPrefix)\(taskID.uuidString)"
    }

    private static let taskReminderPrefix = "task-reminder-"

    private func clearNotification(withIdentifier identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    private func reminderBody(for kind: TaskReminderKind) -> String {
        switch kind {
        case .personalTask:
            return "别忘了处理这条任务。"
        }
    }

    private func mapAvailability(from status: NotificationAuthorizationStatus) -> ServiceAvailability {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return .available
        case .denied, .notDetermined:
            return .notAuthorized
        case .unsupported:
            return .notSupported
        }
    }
}
