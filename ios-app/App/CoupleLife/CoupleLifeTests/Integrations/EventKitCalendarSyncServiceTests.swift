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
}
