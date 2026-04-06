import Foundation

@MainActor
final class ProfileSettingsViewModel: ObservableObject {
    @Published private(set) var healthAvailability: ServiceAvailability = .notSupported
    @Published private(set) var calendarSyncStatus = CalendarSyncStatus(isEnabled: false, availability: .notSupported)
    @Published private(set) var notificationAvailability: ServiceAvailability = .notSupported
    @Published private(set) var cloudSyncAvailability: ServiceAvailability = .notSupported
    @Published private(set) var isLoading = false
    @Published private(set) var isRequestingHealthAuthorization = false
    @Published private(set) var isUpdatingCalendarSync = false

    private let healthDataService: any HealthDataService
    private let calendarSyncController: any CalendarSyncSettingsControlling
    private let notificationScheduler: any NotificationScheduler
    private let cloudSyncService: any CloudSyncService

    init(
        healthDataService: any HealthDataService,
        calendarSyncController: any CalendarSyncSettingsControlling,
        notificationScheduler: any NotificationScheduler,
        cloudSyncService: any CloudSyncService
    ) {
        self.healthDataService = healthDataService
        self.calendarSyncController = calendarSyncController
        self.notificationScheduler = notificationScheduler
        self.cloudSyncService = cloudSyncService
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        healthAvailability = await healthDataService.availability()
        calendarSyncStatus = await calendarSyncController.currentStatus()
        notificationAvailability = await notificationScheduler.availability()
        cloudSyncAvailability = await cloudSyncService.availability()
    }

    func requestHealthAuthorization() async {
        isRequestingHealthAuthorization = true
        defer { isRequestingHealthAuthorization = false }
        healthAvailability = await healthDataService.requestAuthorization()
    }

    func setCalendarSyncEnabled(_ enabled: Bool) async {
        isUpdatingCalendarSync = true
        defer { isUpdatingCalendarSync = false }
        calendarSyncStatus = await calendarSyncController.setSyncEnabled(enabled)
    }
}
