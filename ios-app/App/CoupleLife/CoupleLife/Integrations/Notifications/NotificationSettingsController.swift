import Foundation

final class UserDefaultsNotificationSettingsStore: NotificationSettingsStore {
    private enum Keys {
        static let taskRemindersEnabled = "planning.notifications.task.enabled"
        static let waterReminderEnabled = "planning.notifications.water.enabled"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var isTaskRemindersEnabled: Bool {
        get { userDefaults.bool(forKey: Keys.taskRemindersEnabled) }
        set { userDefaults.set(newValue, forKey: Keys.taskRemindersEnabled) }
    }

    var isWaterReminderEnabled: Bool {
        get { userDefaults.bool(forKey: Keys.waterReminderEnabled) }
        set { userDefaults.set(newValue, forKey: Keys.waterReminderEnabled) }
    }
}

final class DefaultNotificationSettingsController: NotificationSettingsControlling {
    private let notificationScheduler: any NotificationScheduler
    private let settingsStore: any NotificationSettingsStore

    init(
        notificationScheduler: any NotificationScheduler,
        settingsStore: any NotificationSettingsStore
    ) {
        self.notificationScheduler = notificationScheduler
        self.settingsStore = settingsStore
    }

    func currentStatus() async -> NotificationSettingsStatus {
        let availability = await notificationScheduler.availability()
        var isTaskRemindersEnabled = settingsStore.isTaskRemindersEnabled
        var isWaterReminderEnabled = settingsStore.isWaterReminderEnabled

        if availability != .available {
            if isTaskRemindersEnabled {
                settingsStore.isTaskRemindersEnabled = false
                isTaskRemindersEnabled = false
                await notificationScheduler.cancelAllTaskReminders()
            }

            if isWaterReminderEnabled {
                settingsStore.isWaterReminderEnabled = false
                isWaterReminderEnabled = false
                await notificationScheduler.cancelWaterReminder()
            }
        }

        return NotificationSettingsStatus(
            isTaskRemindersEnabled: isTaskRemindersEnabled,
            isWaterReminderEnabled: isWaterReminderEnabled,
            availability: availability
        )
    }

    func setTaskRemindersEnabled(_ enabled: Bool) async -> NotificationSettingsStatus {
        guard enabled else {
            settingsStore.isTaskRemindersEnabled = false
            await notificationScheduler.cancelAllTaskReminders()

            return NotificationSettingsStatus(
                isTaskRemindersEnabled: false,
                isWaterReminderEnabled: settingsStore.isWaterReminderEnabled,
                availability: await notificationScheduler.availability()
            )
        }

        let availability = await notificationScheduler.requestAuthorization()
        let resolvedEnabled = availability == .available
        settingsStore.isTaskRemindersEnabled = resolvedEnabled

        return NotificationSettingsStatus(
            isTaskRemindersEnabled: resolvedEnabled,
            isWaterReminderEnabled: settingsStore.isWaterReminderEnabled,
            availability: availability
        )
    }

    func setWaterReminderEnabled(_ enabled: Bool) async -> NotificationSettingsStatus {
        guard enabled else {
            settingsStore.isWaterReminderEnabled = false
            await notificationScheduler.cancelWaterReminder()

            return NotificationSettingsStatus(
                isTaskRemindersEnabled: settingsStore.isTaskRemindersEnabled,
                isWaterReminderEnabled: false,
                availability: await notificationScheduler.availability()
            )
        }

        let availability = await notificationScheduler.requestAuthorization()
        let resolvedEnabled = availability == .available
        settingsStore.isWaterReminderEnabled = resolvedEnabled

        if resolvedEnabled {
            await notificationScheduler.scheduleWaterReminder()
        }

        return NotificationSettingsStatus(
            isTaskRemindersEnabled: settingsStore.isTaskRemindersEnabled,
            isWaterReminderEnabled: resolvedEnabled,
            availability: availability
        )
    }
}
