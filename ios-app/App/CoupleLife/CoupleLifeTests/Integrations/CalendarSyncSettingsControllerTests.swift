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

    func testCurrentStatusAutoDisablesWhenPermissionWasRevoked() async {
        let service = TestCalendarSyncService()
        service.currentServiceAvailability = .notAuthorized
        let store = TestCalendarSyncSettingsStore(isEnabled: true)
        let controller = DefaultCalendarSyncSettingsController(
            calendarSyncService: service,
            settingsStore: store
        )

        let status = await controller.currentStatus()

        XCTAssertFalse(store.isEnabled)
        XCTAssertEqual(status, CalendarSyncStatus(isEnabled: false, availability: .notAuthorized))
    }

    func testSetSyncEnabledPersistsTrueWhenDefaultCalendarIsMissing() async {
        let service = TestCalendarSyncService()
        service.currentServiceAvailability = .failed("未找到可写入的系统日历。")
        let store = TestCalendarSyncSettingsStore(isEnabled: false)
        let controller = DefaultCalendarSyncSettingsController(
            calendarSyncService: service,
            settingsStore: store
        )

        let status = await controller.setSyncEnabled(true)

        XCTAssertTrue(store.isEnabled)
        XCTAssertEqual(status, CalendarSyncStatus(isEnabled: true, availability: .failed("未找到可写入的系统日历。")))
    }

    func testCurrentStatusKeepsEnabledWhenDefaultCalendarIsMissing() async {
        let service = TestCalendarSyncService()
        service.currentServiceAvailability = .failed("未找到可写入的系统日历。")
        let store = TestCalendarSyncSettingsStore(isEnabled: true)
        let controller = DefaultCalendarSyncSettingsController(
            calendarSyncService: service,
            settingsStore: store
        )

        let status = await controller.currentStatus()

        XCTAssertTrue(store.isEnabled)
        XCTAssertEqual(status, CalendarSyncStatus(isEnabled: true, availability: .failed("未找到可写入的系统日历。")))
    }
}
