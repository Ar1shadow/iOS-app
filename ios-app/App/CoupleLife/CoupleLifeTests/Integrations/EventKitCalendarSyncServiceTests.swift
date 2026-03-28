import EventKit
import XCTest
@testable import CoupleLife

final class EventKitCalendarSyncServiceTests: XCTestCase {
    func testCurrentAvailabilityFailsWhenAuthorizedButNoDefaultCalendarExists() {
        let service = EventKitCalendarSyncService(
            eventStore: EKEventStore(),
            authorizationStatusProvider: { .writeOnly },
            defaultCalendarProvider: { nil }
        )

        XCTAssertEqual(service.currentAvailability(), .failed("未找到可写入的系统日历。"))
    }

    func testRequestAccessReturnsCurrentAvailabilityAfterGrant() async {
        var authorizationStatus: EKAuthorizationStatus = .notDetermined
        let service = EventKitCalendarSyncService(
            eventStore: EKEventStore(),
            authorizationStatusProvider: { authorizationStatus },
            defaultCalendarProvider: { nil },
            requestWriteOnlyAccessProvider: {
                authorizationStatus = .writeOnly
                return true
            }
        )

        let availability = await service.requestAccess()

        XCTAssertEqual(availability, .failed("未找到可写入的系统日历。"))
    }
}
