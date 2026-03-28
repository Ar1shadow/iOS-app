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

    func testUpsertEventUpdatesExistingEventWhenAuthorizedButNoDefaultCalendarExists() throws {
        let eventStore = EKEventStore()
        let existingCalendar = EKCalendar(for: .event, eventStore: eventStore)
        let existingEvent = EKEvent(eventStore: eventStore)
        existingEvent.calendar = existingCalendar

        var saveCallCount = 0
        let service = EventKitCalendarSyncService(
            eventStore: eventStore,
            authorizationStatusProvider: { .writeOnly },
            defaultCalendarProvider: { nil },
            eventProvider: { _ in existingEvent },
            saveEvent: { _ in saveCallCount += 1 }
        )

        let startAt = Date(timeIntervalSince1970: 1_700_000_000)
        let task = TaskItem(
            title: "产检预约",
            startAt: startAt,
            dueAt: startAt.addingTimeInterval(3600),
            isAllDay: false,
            status: .todo,
            planLevel: .day,
            ownerUserId: "u1",
            systemCalendarEventId: "event-123"
        )

        let identifier = try service.upsertEvent(for: task)

        XCTAssertEqual(identifier, "event-123")
        XCTAssertEqual(saveCallCount, 1)
    }

    func testDeleteEventRemovesExistingEventWhenAuthorizedButNoDefaultCalendarExists() throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)

        var removedEvent: EKEvent?
        let service = EventKitCalendarSyncService(
            eventStore: eventStore,
            authorizationStatusProvider: { .writeOnly },
            defaultCalendarProvider: { nil },
            eventProvider: { _ in event },
            removeEvent: { removedEvent = $0 }
        )

        try service.deleteEvent(withIdentifier: "event-123")

        XCTAssertTrue(removedEvent === event)
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
