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
        let activeCoupleSpaceStore = UserDefaultsActiveCoupleSpaceStore()
        let taskStore = SwiftDataCloudSyncTaskStore(context: modelContainer.mainContext)
        let recordStore = SwiftDataCloudSyncRecordStore(context: modelContainer.mainContext)
        return AppContainer(
            calendarSync: EventKitCalendarSyncService(),
            calendarSyncSettings: UserDefaultsCalendarSyncSettingsStore(),
            healthData: HealthKitHealthDataService(
                repository: SwiftDataHealthSnapshotRepository(context: modelContainer.mainContext)
            ),
            notifications: UserNotificationScheduler(),
            notificationSettings: UserDefaultsNotificationSettingsStore(),
            activeCoupleSpaceStore: activeCoupleSpaceStore,
            cloudSync: DefaultCloudSyncService(
                client: CloudKitCloudSyncClient(),
                taskSource: taskStore,
                recordSource: recordStore,
                taskSink: taskStore,
                recordSink: recordStore,
                activeCoupleSpaceStore: activeCoupleSpaceStore
            )
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
