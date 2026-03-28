import SwiftData
import SwiftUI

struct AppContainer {
    let calendarSync: CalendarSyncService
    let healthData: HealthDataService
    let notifications: NotificationScheduler
    let cloudSync: CloudSyncService

    static let `default` = AppContainer(
        calendarSync: NoopCalendarSyncService(),
        healthData: NoopHealthDataService(),
        notifications: NoopNotificationScheduler(),
        cloudSync: NoopCloudSyncService()
    )

    @MainActor
    static func live(modelContainer: ModelContainer) -> AppContainer {
        AppContainer(
            calendarSync: NoopCalendarSyncService(),
            healthData: HealthKitHealthDataService(
                repository: SwiftDataHealthSnapshotRepository(context: modelContainer.mainContext)
            ),
            notifications: NoopNotificationScheduler(),
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
