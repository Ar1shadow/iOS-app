import XCTest
@testable import CoupleLife

final class NotificationSettingsControllerTests: XCTestCase {
    func testSetTaskRemindersEnabledPersistsTrueAfterAuthorizedAccess() async {
        let scheduler = TestNotificationScheduler()
        scheduler.requestAuthorizationResult = .available
        let store = TestNotificationSettingsStore(isTaskRemindersEnabled: false)
        let controller = DefaultNotificationSettingsController(
            notificationScheduler: scheduler,
            settingsStore: store
        )

        let status = await controller.setTaskRemindersEnabled(true)

        XCTAssertTrue(store.isTaskRemindersEnabled)
        XCTAssertEqual(
            status,
            NotificationSettingsStatus(
                isTaskRemindersEnabled: true,
                isWaterReminderEnabled: false,
                availability: .available
            )
        )
    }

    func testSetWaterReminderEnabledRequestsAuthorizationAndSchedulesReminder() async {
        let scheduler = TestNotificationScheduler()
        scheduler.requestAuthorizationResult = .available
        let store = TestNotificationSettingsStore(isTaskRemindersEnabled: false, isWaterReminderEnabled: false)
        let controller = DefaultNotificationSettingsController(
            notificationScheduler: scheduler,
            settingsStore: store
        )

        let status = await controller.setWaterReminderEnabled(true)

        XCTAssertTrue(store.isWaterReminderEnabled)
        XCTAssertTrue(scheduler.didScheduleWaterReminder)
        XCTAssertEqual(
            status,
            NotificationSettingsStatus(
                isTaskRemindersEnabled: false,
                isWaterReminderEnabled: true,
                availability: .available
            )
        )
    }

    func testSetTaskRemindersEnabledLeavesDisabledWhenAuthorizationDenied() async {
        let scheduler = TestNotificationScheduler()
        scheduler.requestAuthorizationResult = .notAuthorized
        let store = TestNotificationSettingsStore(isTaskRemindersEnabled: false)
        let controller = DefaultNotificationSettingsController(
            notificationScheduler: scheduler,
            settingsStore: store
        )

        let status = await controller.setTaskRemindersEnabled(true)

        XCTAssertFalse(store.isTaskRemindersEnabled)
        XCTAssertEqual(
            status,
            NotificationSettingsStatus(
                isTaskRemindersEnabled: false,
                isWaterReminderEnabled: false,
                availability: .notAuthorized
            )
        )
    }

    func testCurrentStatusAutoDisablesWhenPermissionWasRevoked() async {
        let scheduler = TestNotificationScheduler()
        scheduler.serviceAvailability = .notAuthorized
        let store = TestNotificationSettingsStore(isTaskRemindersEnabled: true, isWaterReminderEnabled: true)
        let controller = DefaultNotificationSettingsController(
            notificationScheduler: scheduler,
            settingsStore: store
        )

        let status = await controller.currentStatus()

        XCTAssertFalse(store.isTaskRemindersEnabled)
        XCTAssertFalse(store.isWaterReminderEnabled)
        XCTAssertEqual(
            status,
            NotificationSettingsStatus(
                isTaskRemindersEnabled: false,
                isWaterReminderEnabled: false,
                availability: .notAuthorized
            )
        )
    }

    func testDisablingWaterReminderCancelsScheduledReminder() async {
        let scheduler = TestNotificationScheduler()
        let store = TestNotificationSettingsStore(isTaskRemindersEnabled: false, isWaterReminderEnabled: true)
        let controller = DefaultNotificationSettingsController(
            notificationScheduler: scheduler,
            settingsStore: store
        )

        let status = await controller.setWaterReminderEnabled(false)

        XCTAssertFalse(store.isWaterReminderEnabled)
        XCTAssertTrue(scheduler.didCancelWaterReminder)
        XCTAssertEqual(
            status,
            NotificationSettingsStatus(
                isTaskRemindersEnabled: false,
                isWaterReminderEnabled: false,
                availability: .available
            )
        )
    }
}
