import Foundation
import XCTest
@testable import CoupleLife

final class TestNotificationSettingsStore: NotificationSettingsStore {
    var isTaskRemindersEnabled: Bool
    var isWaterReminderEnabled: Bool

    init(
        isTaskRemindersEnabled: Bool,
        isWaterReminderEnabled: Bool = false
    ) {
        self.isTaskRemindersEnabled = isTaskRemindersEnabled
        self.isWaterReminderEnabled = isWaterReminderEnabled
    }
}

final class TestNotificationScheduler: NotificationScheduler {
    var serviceAvailability: ServiceAvailability = .available
    var requestAuthorizationResult: ServiceAvailability = .available
    var scheduledTaskReminders: [TaskReminderPayload] = []
    var cancelledTaskIDs: [UUID] = []
    var didCancelAllTaskReminders = false
    var didScheduleWaterReminder = false
    var didCancelWaterReminder = false
    var operationExpectation: XCTestExpectation?
    var onCancelAllTaskReminders: (() async -> Void)?
    var onScheduleTaskReminder: (() async -> Void)?

    func availability() async -> ServiceAvailability {
        serviceAvailability
    }

    func requestAuthorization() async -> ServiceAvailability {
        requestAuthorizationResult
    }

    func scheduleTaskReminder(_ reminder: TaskReminderPayload) async {
        await onScheduleTaskReminder?()
        scheduledTaskReminders.append(reminder)
        operationExpectation?.fulfill()
    }

    func cancelTaskReminder(id: UUID) async {
        cancelledTaskIDs.append(id)
        operationExpectation?.fulfill()
    }

    func cancelAllTaskReminders() async {
        await onCancelAllTaskReminders?()
        didCancelAllTaskReminders = true
        operationExpectation?.fulfill()
    }

    func scheduleWaterReminder() async {
        didScheduleWaterReminder = true
    }

    func cancelWaterReminder() async {
        didCancelWaterReminder = true
    }
}

final class FakeUserNotificationCenter: UserNotificationCenterClient {
    var authorizationStatus: NotificationAuthorizationStatus = .notDetermined
    var requestAuthorizationResult = true
    var requestAuthorizationError: Error?
    var addedRequests: [NotificationRequestDescriptor] = []
    var pendingRequests: [NotificationRequestDescriptor] = []
    var removedPendingIdentifiers: [[String]] = []
    var removedDeliveredIdentifiers: [[String]] = []

    func getAuthorizationStatus() async -> NotificationAuthorizationStatus {
        authorizationStatus
    }

    func requestAuthorization(options: NotificationAuthorizationOptions) async throws -> Bool {
        if let requestAuthorizationError {
            throw requestAuthorizationError
        }
        return requestAuthorizationResult
    }

    func add(_ request: NotificationRequestDescriptor) async throws {
        addedRequests.append(request)
        pendingRequests.removeAll { $0.identifier == request.identifier }
        pendingRequests.append(request)
    }

    func pendingNotificationRequests() async -> [NotificationRequestDescriptor] {
        pendingRequests
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedPendingIdentifiers.append(identifiers)
        pendingRequests.removeAll { identifiers.contains($0.identifier) }
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        removedDeliveredIdentifiers.append(identifiers)
    }
}

actor AsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}
