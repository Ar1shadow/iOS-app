import Foundation

final class UserDefaultsCalendarSyncSettingsStore: CalendarSyncSettingsStore {
    private enum Keys {
        static let isEnabled = "planning.calendarSync.enabled"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var isEnabled: Bool {
        get { userDefaults.bool(forKey: Keys.isEnabled) }
        set { userDefaults.set(newValue, forKey: Keys.isEnabled) }
    }
}

final class DefaultCalendarSyncSettingsController: CalendarSyncSettingsControlling {
    private let calendarSyncService: any CalendarSyncService
    private let settingsStore: any CalendarSyncSettingsStore

    init(
        calendarSyncService: any CalendarSyncService,
        settingsStore: any CalendarSyncSettingsStore
    ) {
        self.calendarSyncService = calendarSyncService
        self.settingsStore = settingsStore
    }

    func currentStatus() async -> CalendarSyncStatus {
        CalendarSyncStatus(
            isEnabled: settingsStore.isEnabled,
            availability: await calendarSyncService.availability()
        )
    }

    func setSyncEnabled(_ enabled: Bool) async -> CalendarSyncStatus {
        guard enabled else {
            settingsStore.isEnabled = false
            return CalendarSyncStatus(isEnabled: false, availability: calendarSyncService.currentAvailability())
        }

        let availability = await calendarSyncService.requestAccess()
        let resolvedEnabled = availability == .available
        settingsStore.isEnabled = resolvedEnabled

        return CalendarSyncStatus(isEnabled: resolvedEnabled, availability: availability)
    }
}
