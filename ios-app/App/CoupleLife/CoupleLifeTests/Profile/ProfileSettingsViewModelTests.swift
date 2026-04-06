import XCTest
@testable import CoupleLife

@MainActor
final class ProfileSettingsViewModelTests: XCTestCase {
    func testLoadFetchesAndStoresStatuses() async {
        let healthService = StubHealthDataService(
            availability: .notAuthorized,
            requestAuthorizationResult: .available
        )
        let calendarService = TestCalendarSyncService()
        calendarService.currentServiceAvailability = .available
        let calendarStore = TestCalendarSyncSettingsStore(isEnabled: true)
        let calendarController = DefaultCalendarSyncSettingsController(
            calendarSyncService: calendarService,
            settingsStore: calendarStore
        )
        let notifications = StubNotificationScheduler(availability: .notSupported)
        let cloudSync = StubCloudSyncService(availability: .notSupported)
        let viewModel = ProfileSettingsViewModel(
            healthDataService: healthService,
            calendarSyncController: calendarController,
            notificationScheduler: notifications,
            cloudSyncService: cloudSync
        )

        XCTAssertFalse(viewModel.hasLoadedOnce)

        await viewModel.load()

        XCTAssertTrue(viewModel.hasLoadedOnce)
        XCTAssertEqual(viewModel.healthAvailability, .notAuthorized)
        XCTAssertEqual(
            viewModel.calendarSyncStatus,
            CalendarSyncStatus(isEnabled: true, availability: .available)
        )
        XCTAssertEqual(viewModel.notificationAvailability, .notSupported)
        XCTAssertEqual(viewModel.cloudSyncAvailability, .notSupported)
    }

    func testRequestHealthAuthorizationTriggersServiceAndUpdatesState() async {
        let healthService = StubHealthDataService(
            availability: .notAuthorized,
            requestAuthorizationResult: .available
        )
        let viewModel = ProfileSettingsViewModel(
            healthDataService: healthService,
            calendarSyncController: DefaultCalendarSyncSettingsController(
                calendarSyncService: TestCalendarSyncService(),
                settingsStore: TestCalendarSyncSettingsStore(isEnabled: false)
            ),
            notificationScheduler: StubNotificationScheduler(availability: .notSupported),
            cloudSyncService: StubCloudSyncService(availability: .notSupported)
        )

        await viewModel.load()
        await viewModel.requestHealthAuthorization()

        XCTAssertEqual(healthService.requestAuthorizationCallCount, 1)
        XCTAssertEqual(viewModel.healthAvailability, .available)
        XCTAssertFalse(viewModel.isRequestingHealthAuthorization)
    }

    func testSetCalendarSyncEnabledUsesControllerAndPublishesReturnedStatus() async {
        let calendarService = TestCalendarSyncService()
        calendarService.currentServiceAvailability = .available
        let calendarStore = TestCalendarSyncSettingsStore(isEnabled: false)
        let viewModel = ProfileSettingsViewModel(
            healthDataService: StubHealthDataService(
                availability: .notSupported,
                requestAuthorizationResult: .notSupported
            ),
            calendarSyncController: DefaultCalendarSyncSettingsController(
                calendarSyncService: calendarService,
                settingsStore: calendarStore
            ),
            notificationScheduler: StubNotificationScheduler(availability: .notSupported),
            cloudSyncService: StubCloudSyncService(availability: .notSupported)
        )

        await viewModel.load()
        await viewModel.setCalendarSyncEnabled(true)

        XCTAssertEqual(viewModel.calendarSyncStatus, CalendarSyncStatus(isEnabled: true, availability: .available))
        XCTAssertTrue(calendarStore.isEnabled)
        XCTAssertFalse(viewModel.isUpdatingCalendarSync)
    }

    func testRequestNotificationAuthorizationTriggersSchedulerAndUpdatesState() async {
        let notificationScheduler = StubNotificationScheduler(
            availability: .notAuthorized,
            requestAuthorizationResult: .available
        )
        let notificationStore = TestNotificationSettingsStore(
            isTaskRemindersEnabled: false,
            isWaterReminderEnabled: false
        )
        let viewModel = ProfileSettingsViewModel(
            healthDataService: StubHealthDataService(
                availability: .notSupported,
                requestAuthorizationResult: .notSupported
            ),
            calendarSyncController: DefaultCalendarSyncSettingsController(
                calendarSyncService: TestCalendarSyncService(),
                settingsStore: TestCalendarSyncSettingsStore(isEnabled: false)
            ),
            notificationController: DefaultNotificationSettingsController(
                notificationScheduler: notificationScheduler,
                settingsStore: notificationStore
            ),
            notificationScheduler: notificationScheduler,
            cloudSyncService: StubCloudSyncService(availability: .notSupported)
        )

        await viewModel.load()
        await viewModel.requestNotificationAuthorization()

        XCTAssertEqual(notificationScheduler.requestAuthorizationCallCount, 1)
        XCTAssertEqual(viewModel.notificationAvailability, .available)
        XCTAssertEqual(
            viewModel.notificationSettingsStatus,
            NotificationSettingsStatus(
                isTaskRemindersEnabled: false,
                isWaterReminderEnabled: false,
                availability: .available
            )
        )
        XCTAssertFalse(viewModel.isRequestingNotificationAuthorization)
    }

    func testLoadReconcilesNotificationSettingsAndCancelsStoredRemindersWhenPermissionRevoked() async {
        let notificationScheduler = TestNotificationScheduler()
        notificationScheduler.serviceAvailability = .notAuthorized
        let notificationStore = TestNotificationSettingsStore(
            isTaskRemindersEnabled: true,
            isWaterReminderEnabled: true
        )
        let notificationController = DefaultNotificationSettingsController(
            notificationScheduler: notificationScheduler,
            settingsStore: notificationStore
        )
        let viewModel = ProfileSettingsViewModel(
            healthDataService: StubHealthDataService(
                availability: .notSupported,
                requestAuthorizationResult: .notSupported
            ),
            calendarSyncController: DefaultCalendarSyncSettingsController(
                calendarSyncService: TestCalendarSyncService(),
                settingsStore: TestCalendarSyncSettingsStore(isEnabled: false)
            ),
            notificationController: notificationController,
            notificationScheduler: notificationScheduler,
            cloudSyncService: StubCloudSyncService(availability: .notSupported)
        )

        await viewModel.load()

        XCTAssertEqual(
            viewModel.notificationSettingsStatus,
            NotificationSettingsStatus(
                isTaskRemindersEnabled: false,
                isWaterReminderEnabled: false,
                availability: .notAuthorized
            )
        )
        XCTAssertEqual(viewModel.notificationAvailability, .notAuthorized)
        XCTAssertFalse(notificationStore.isTaskRemindersEnabled)
        XCTAssertFalse(notificationStore.isWaterReminderEnabled)
        XCTAssertTrue(notificationScheduler.didCancelAllTaskReminders)
        XCTAssertTrue(notificationScheduler.didCancelWaterReminder)
    }
}

private final class StubHealthDataService: HealthDataService {
    private let availabilityValue: ServiceAvailability
    private let requestAuthorizationValue: ServiceAvailability

    private(set) var requestAuthorizationCallCount = 0

    init(
        availability: ServiceAvailability,
        requestAuthorizationResult: ServiceAvailability
    ) {
        self.availabilityValue = availability
        self.requestAuthorizationValue = requestAuthorizationResult
    }

    func availability() async -> ServiceAvailability {
        availabilityValue
    }

    func requestAuthorization() async -> ServiceAvailability {
        requestAuthorizationCallCount += 1
        return requestAuthorizationValue
    }

    func refreshTodaySnapshot(ownerUserId: String, asOf date: Date, force: Bool) async -> ServiceAvailability {
        .notSupported
    }
}

private final class StubNotificationScheduler: NotificationScheduler {
    private var currentAvailability: ServiceAvailability
    let requestAuthorizationValue: ServiceAvailability

    private(set) var requestAuthorizationCallCount = 0

    init(
        availability: ServiceAvailability,
        requestAuthorizationResult: ServiceAvailability = .notSupported
    ) {
        self.currentAvailability = availability
        self.requestAuthorizationValue = requestAuthorizationResult
    }

    func availability() async -> ServiceAvailability {
        currentAvailability
    }

    func requestAuthorization() async -> ServiceAvailability {
        requestAuthorizationCallCount += 1
        currentAvailability = requestAuthorizationValue
        return requestAuthorizationValue
    }

    func scheduleTaskReminder(_ reminder: TaskReminderPayload) async {}
    func cancelTaskReminder(id: UUID) async {}
    func cancelAllTaskReminders() async {}
    func scheduleWaterReminder() async {}
    func cancelWaterReminder() async {}
}

private struct StubCloudSyncService: CloudSyncService {
    let availabilityValue: ServiceAvailability

    init(availability: ServiceAvailability) {
        self.availabilityValue = availability
    }

    func availability() async -> ServiceAvailability {
        availabilityValue
    }
}
