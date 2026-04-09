import Foundation

@MainActor
final class ProfileSettingsViewModel: ObservableObject {
    @Published private(set) var hasLoadedOnce = false
    @Published private(set) var healthAvailability: ServiceAvailability = .notSupported
    @Published private(set) var calendarSyncStatus = CalendarSyncStatus(isEnabled: false, availability: .notSupported)
    @Published private(set) var notificationSettingsStatus = NotificationSettingsStatus(
        isTaskRemindersEnabled: false,
        isWaterReminderEnabled: false,
        availability: .notSupported
    )
    @Published private(set) var notificationAvailability: ServiceAvailability = .notSupported
    @Published private(set) var cloudSyncStatus: CloudSyncStatus = .unsupported
    @Published private(set) var cloudSyncAvailability: ServiceAvailability = .notSupported
    @Published private(set) var isLoading = false
    @Published private(set) var isRequestingHealthAuthorization = false
    @Published private(set) var isRequestingNotificationAuthorization = false
    @Published private(set) var isUpdatingCalendarSync = false
    @Published private(set) var isRefreshingCloudSync = false

    private let healthDataService: any HealthDataService
    private let calendarSyncController: any CalendarSyncSettingsControlling
    private let notificationController: any NotificationSettingsControlling
    private let notificationScheduler: any NotificationScheduler
    private let cloudSyncService: any CloudSyncService

    init(
        healthDataService: any HealthDataService,
        calendarSyncController: any CalendarSyncSettingsControlling,
        notificationController: any NotificationSettingsControlling = DefaultNotificationSettingsController(
            notificationScheduler: NoopNotificationScheduler(),
            settingsStore: UserDefaultsNotificationSettingsStore()
        ),
        notificationScheduler: any NotificationScheduler,
        cloudSyncService: any CloudSyncService
    ) {
        self.healthDataService = healthDataService
        self.calendarSyncController = calendarSyncController
        self.notificationController = notificationController
        self.notificationScheduler = notificationScheduler
        self.cloudSyncService = cloudSyncService
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        healthAvailability = await healthDataService.availability()
        calendarSyncStatus = await calendarSyncController.currentStatus()
        notificationSettingsStatus = await notificationController.currentStatus()
        notificationAvailability = notificationSettingsStatus.availability
        cloudSyncStatus = await cloudSyncService.currentStatus()
        cloudSyncAvailability = cloudSyncStatus.availability
        hasLoadedOnce = true
    }

    func requestHealthAuthorization() async {
        isRequestingHealthAuthorization = true
        defer { isRequestingHealthAuthorization = false }
        healthAvailability = await healthDataService.requestAuthorization()
    }

    func requestNotificationAuthorization() async {
        isRequestingNotificationAuthorization = true
        defer { isRequestingNotificationAuthorization = false }
        notificationAvailability = await notificationScheduler.requestAuthorization()
        notificationSettingsStatus = await notificationController.currentStatus()
        notificationAvailability = notificationSettingsStatus.availability
    }

    func setCalendarSyncEnabled(_ enabled: Bool) async {
        isUpdatingCalendarSync = true
        defer { isUpdatingCalendarSync = false }
        calendarSyncStatus = await calendarSyncController.setSyncEnabled(enabled)
    }

    func refreshCloudSync() async {
        isRefreshingCloudSync = true
        defer { isRefreshingCloudSync = false }
        cloudSyncStatus = await cloudSyncService.refresh()
        cloudSyncAvailability = cloudSyncStatus.availability
    }
}
