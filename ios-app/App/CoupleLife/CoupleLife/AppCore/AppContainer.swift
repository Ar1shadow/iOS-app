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

