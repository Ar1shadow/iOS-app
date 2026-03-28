import EventKit
import XCTest
@testable import CoupleLife

final class EventKitCalendarSyncServiceTests: XCTestCase {
    func testCurrentAvailabilityStaysAvailableWhenAuthorizedButNoDefaultCalendarExists() {
        let service = EventKitCalendarSyncService(
            eventStore: EKEventStore(),
            authorizationStatusProvider: { .writeOnly },
            defaultCalendarProvider: { nil }
        )

        XCTAssertEqual(service.currentAvailability(), .available)
    }

    func testRequestAccessReturnsCurrentAvailabilityAfterGrant() async {
        var authorizationStatus: EKAuthorizationStatus = .notDetermined
        let service = EventKitCalendarSyncService(
            eventStore: EKEventStore(),
            authorizationStatusProvider: { authorizationStatus },
            defaultCalendarProvider: { nil },
            requestWriteOnlyAccessProvider: {
                authorizationStatus = .restricted
                return true
            }
        )

        let availability = await service.requestAccess()

        XCTAssertEqual(availability, .notAuthorized)
    }

    func testDeleteEventAllowsExistingLinkedEventWithoutDefaultCalendar() throws {
        let eventStore = EKEventStore()
        let existingEvent = EKEvent(eventStore: eventStore)
        var removedEvents: [EKEvent] = []
        let service = EventKitCalendarSyncService(
            eventStore: eventStore,
            authorizationStatusProvider: { .writeOnly },
            defaultCalendarProvider: { nil },
            eventProvider: { identifier in
                identifier == "event-123" ? existingEvent : nil
            },
            removeEvent: { event in
                removedEvents.append(event)
            }
        )

        XCTAssertNoThrow(try service.deleteEvent(withIdentifier: "event-123"))
        XCTAssertEqual(removedEvents.count, 1)
        XCTAssertTrue(removedEvents.first === existingEvent)
    }

    func testUpsertExistingEventAllowsMissingDefaultCalendar() throws {
        let eventStore = EKEventStore()
        let existingEvent = EKEvent(eventStore: eventStore)
        existingEvent.calendar = EKCalendar(for: .event, eventStore: eventStore)
        var savedEvents: [EKEvent] = []
        let service = EventKitCalendarSyncService(
            eventStore: eventStore,
            authorizationStatusProvider: { .writeOnly },
            defaultCalendarProvider: { nil },
            eventProvider: { identifier in
                identifier == "event-123" ? existingEvent : nil
            },
            saveEvent: { event in
                savedEvents.append(event)
            }
        )
        let task = TaskItem(
            title: "产检预约",
            startAt: Date(timeIntervalSince1970: 1_700_000_000),
            dueAt: nil,
            status: .todo,
            planLevel: .day,
            ownerUserId: "local",
            systemCalendarEventId: "event-123"
        )

        let eventIdentifier = try service.upsertEvent(for: task)

        XCTAssertEqual(eventIdentifier, "event-123")
        XCTAssertEqual(savedEvents.count, 1)
        XCTAssertTrue(savedEvents.first === existingEvent)
    }
}
