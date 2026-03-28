import XCTest
@testable import CoupleLife

final class CalendarSyncSettingsControllerTests: XCTestCase {
    func testSetSyncEnabledPersistsTrueAfterAuthorizedAccess() async {
        let service = TestCalendarSyncService()
        service.currentServiceAvailability = .available
        let store = TestCalendarSyncSettingsStore(isEnabled: false)
        let controller = DefaultCalendarSyncSettingsController(
            calendarSyncService: service,
            settingsStore: store
        )

        let status = await controller.setSyncEnabled(true)

        XCTAssertTrue(store.isEnabled)
        XCTAssertEqual(status, CalendarSyncStatus(isEnabled: true, availability: .available))
    }

    func testSetSyncEnabledLeavesDisabledWhenAuthorizationDenied() async {
        let service = TestCalendarSyncService()
        service.currentServiceAvailability = .notAuthorized
        let store = TestCalendarSyncSettingsStore(isEnabled: false)
        let controller = DefaultCalendarSyncSettingsController(
            calendarSyncService: service,
            settingsStore: store
        )

        let status = await controller.setSyncEnabled(true)

        XCTAssertFalse(store.isEnabled)
        XCTAssertEqual(status, CalendarSyncStatus(isEnabled: false, availability: .notAuthorized))
    }
}
