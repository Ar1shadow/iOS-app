import SwiftData
import SwiftUI

struct AppContainer {
    let calendarSync: CalendarSyncService
    let calendarSyncSettings: CalendarSyncSettingsStore
    let healthData: HealthDataService
    let notifications: NotificationScheduler
    let notificationSettings: NotificationSettingsStore
    let activeCoupleSpaceStore: ActiveCoupleSpaceStore
    let cloudSync: CloudSyncService

    static let `default` = AppContainer(
        calendarSync: EventKitCalendarSyncService(),
        calendarSyncSettings: UserDefaultsCalendarSyncSettingsStore(),
        healthData: NoopHealthDataService(),
        notifications: UserNotificationScheduler(),
        notificationSettings: UserDefaultsNotificationSettingsStore(),
        activeCoupleSpaceStore: UserDefaultsActiveCoupleSpaceStore(),
        cloudSync: NoopCloudSyncService()
    )

    @MainActor
    static func live(modelContainer: ModelContainer) -> AppContainer {
        AppContainer(
            calendarSync: EventKitCalendarSyncService(),
            calendarSyncSettings: UserDefaultsCalendarSyncSettingsStore(),
            healthData: HealthKitHealthDataService(
                repository: SwiftDataHealthSnapshotRepository(context: modelContainer.mainContext)
            ),
            notifications: UserNotificationScheduler(),
            notificationSettings: UserDefaultsNotificationSettingsStore(),
            activeCoupleSpaceStore: UserDefaultsActiveCoupleSpaceStore(),
            cloudSync: NoopCloudSyncService()
        )
    }
}

private struct AppContainerKey: EnvironmentKey {
    static let defaultValue: AppContainer = .default
}

extension EnvironmentValues {
    var appContainer: AppContainer {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}
