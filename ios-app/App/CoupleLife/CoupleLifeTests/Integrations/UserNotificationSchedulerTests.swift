import XCTest
@testable import CoupleLife

final class UserNotificationSchedulerTests: XCTestCase {
    func testAvailabilityMapsDeniedToNotAuthorized() async {
        let center = FakeUserNotificationCenter()
        center.authorizationStatus = .denied
        let scheduler = UserNotificationScheduler(notificationCenter: center)

        let availability = await scheduler.availability()

        XCTAssertEqual(availability, .notAuthorized)
    }

    func testScheduleTaskReminderReplacesExistingPendingRequest() async {
        let center = FakeUserNotificationCenter()
        let calendar = Calendar(identifier: .gregorian)
        let fireDate = Date(timeIntervalSince1970: 1_700_003_600)
        let reminder = TaskReminderPayload(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            title: "产检预约",
            fireDate: fireDate,
            kind: .personalTask
        )
        let scheduler = UserNotificationScheduler(
            notificationCenter: center,
            calendar: calendar,
            nowProvider: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        await scheduler.scheduleTaskReminder(reminder)

        XCTAssertEqual(center.removedPendingIdentifiers, [[UserNotificationScheduler.taskReminderIdentifier(for: reminder.id)]])
        XCTAssertEqual(center.removedDeliveredIdentifiers, [[UserNotificationScheduler.taskReminderIdentifier(for: reminder.id)]])
        XCTAssertEqual(center.addedRequests.count, 1)
        XCTAssertEqual(center.addedRequests.first?.identifier, UserNotificationScheduler.taskReminderIdentifier(for: reminder.id))
        XCTAssertEqual(center.addedRequests.first?.title, "产检预约")
        XCTAssertEqual(center.addedRequests.first?.repeats, false)
        XCTAssertEqual(center.addedRequests.first?.dateComponents.year, 2023)
    }

    func testScheduleTaskReminderSkipsPastDate() async {
        let center = FakeUserNotificationCenter()
        let scheduler = UserNotificationScheduler(
            notificationCenter: center,
            nowProvider: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
        let reminder = TaskReminderPayload(
            id: UUID(),
            title: "过期任务",
            fireDate: Date(timeIntervalSince1970: 1_699_999_000),
            kind: .personalTask
        )

        await scheduler.scheduleTaskReminder(reminder)

        XCTAssertTrue(center.addedRequests.isEmpty)
    }

    func testScheduleWaterReminderCreatesRepeatingRequestAtTenAM() async {
        let center = FakeUserNotificationCenter()
        let scheduler = UserNotificationScheduler(notificationCenter: center)

        await scheduler.scheduleWaterReminder()

        XCTAssertEqual(center.addedRequests.count, 1)
        XCTAssertEqual(center.addedRequests.first?.identifier, UserNotificationScheduler.waterReminderIdentifier)
        XCTAssertEqual(center.addedRequests.first?.repeats, true)
        XCTAssertEqual(center.addedRequests.first?.dateComponents.hour, 10)
        XCTAssertEqual(center.addedRequests.first?.dateComponents.minute, 0)
    }

    func testCancelTaskReminderRemovesPendingAndDeliveredRequests() async {
        let center = FakeUserNotificationCenter()
        let taskID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let scheduler = UserNotificationScheduler(notificationCenter: center)

        await scheduler.cancelTaskReminder(id: taskID)

        let identifier = UserNotificationScheduler.taskReminderIdentifier(for: taskID)
        XCTAssertEqual(center.removedPendingIdentifiers, [[identifier]])
        XCTAssertEqual(center.removedDeliveredIdentifiers, [[identifier]])
    }
}
