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
    @Published private(set) var cloudShareAcceptanceStatus: CloudShareAcceptanceStatus = .unsupported
    @Published var cloudShareAcceptanceURLInput: String = ""
    @Published private(set) var cloudShareInvitationStatus: CloudShareInvitationStatus = .unsupported
    @Published private(set) var isLoading = false
    @Published private(set) var isRequestingHealthAuthorization = false
    @Published private(set) var isRequestingNotificationAuthorization = false
    @Published private(set) var isUpdatingCalendarSync = false
    @Published private(set) var isRefreshingCloudSync = false
    @Published private(set) var isAcceptingCloudShare = false
    @Published private(set) var isMutatingCloudShareInvitation = false

    private let healthDataService: any HealthDataService
    private let calendarSyncController: any CalendarSyncSettingsControlling
    private let notificationController: any NotificationSettingsControlling
    private let notificationScheduler: any NotificationScheduler
    private let cloudSyncService: any CloudSyncService
    private let cloudShareAcceptanceService: any CloudShareAcceptanceService
    private let cloudShareInvitationService: any CloudShareInvitationService

    init(
        healthDataService: any HealthDataService,
        calendarSyncController: any CalendarSyncSettingsControlling,
        notificationController: any NotificationSettingsControlling = DefaultNotificationSettingsController(
            notificationScheduler: NoopNotificationScheduler(),
            settingsStore: UserDefaultsNotificationSettingsStore()
        ),
        notificationScheduler: any NotificationScheduler,
        cloudSyncService: any CloudSyncService,
        cloudShareAcceptanceService: any CloudShareAcceptanceService,
        cloudShareInvitationService: any CloudShareInvitationService
    ) {
        self.healthDataService = healthDataService
        self.calendarSyncController = calendarSyncController
        self.notificationController = notificationController
        self.notificationScheduler = notificationScheduler
        self.cloudSyncService = cloudSyncService
        self.cloudShareAcceptanceService = cloudShareAcceptanceService
        self.cloudShareInvitationService = cloudShareInvitationService
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
        cloudShareAcceptanceStatus = await cloudShareAcceptanceService.currentStatus()
        cloudShareInvitationStatus = await cloudShareInvitationService.currentStatus()
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

    func refreshCloudShareAcceptanceStatus() async {
        cloudShareAcceptanceStatus = await cloudShareAcceptanceService.currentStatus()
    }

    func acceptCloudShareFromInput() async {
        guard let url = URL(string: cloudShareAcceptanceURLInput.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }

        isAcceptingCloudShare = true
        defer { isAcceptingCloudShare = false }
        cloudShareAcceptanceStatus = await cloudShareAcceptanceService.acceptShare(from: url)
    }

    func retryLastCloudShareAcceptance() async {
        guard let url = cloudShareAcceptanceStatus.lastURL else { return }

        isAcceptingCloudShare = true
        defer { isAcceptingCloudShare = false }
        cloudShareAcceptanceStatus = await cloudShareAcceptanceService.acceptShare(from: url)
    }

    func refreshCloudShareInvitationStatus() async {
        cloudShareInvitationStatus = await cloudShareInvitationService.currentStatus()
    }

    func createCoupleShare() async {
        isMutatingCloudShareInvitation = true
        defer { isMutatingCloudShareInvitation = false }
        cloudShareInvitationStatus = await cloudShareInvitationService.createShare()
        NotificationCenter.default.post(name: CloudShareNotifications.invitationDidUpdate, object: nil)
    }

    func revokeCoupleShare() async {
        isMutatingCloudShareInvitation = true
        defer { isMutatingCloudShareInvitation = false }
        cloudShareInvitationStatus = await cloudShareInvitationService.revokeShare()
        NotificationCenter.default.post(name: CloudShareNotifications.invitationDidUpdate, object: nil)
    }

    func reinviteCoupleShare() async {
        isMutatingCloudShareInvitation = true
        defer { isMutatingCloudShareInvitation = false }
        cloudShareInvitationStatus = await cloudShareInvitationService.reinvite()
        NotificationCenter.default.post(name: CloudShareNotifications.invitationDidUpdate, object: nil)
    }
}
