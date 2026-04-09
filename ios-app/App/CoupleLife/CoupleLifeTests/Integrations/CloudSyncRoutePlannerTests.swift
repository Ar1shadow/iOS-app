import XCTest
@testable import CoupleLife

final class CloudSyncRoutePlannerTests: XCTestCase {
    func testPlansCoupleSharedTaskForPrivateAndSharedScopes() {
        let task = TaskItem(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            title: "产检预约",
            detail: "协和医院 10:00",
            startAt: Date(timeIntervalSince1970: 1_000),
            dueAt: Date(timeIntervalSince1970: 2_000),
            isAllDay: false,
            priority: 2,
            status: .todo,
            planLevel: .day,
            ownerUserId: "local",
            coupleSpaceId: "SPACE-1",
            visibility: .coupleShared,
            source: .manual,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200),
            version: 3
        )

        let plan = CloudSyncRoutePlanner().plan(task: task)

        XCTAssertEqual(plan.privateRecord.scope, .private)
        XCTAssertEqual(plan.privateRecord.payload.detail, "协和医院 10:00")
        XCTAssertEqual(plan.sharedRecord?.scope, .shared)
        XCTAssertEqual(plan.sharedRecord?.payload.title, "产检预约")
        XCTAssertEqual(plan.sharedRecord?.payload.detail, "协和医院 10:00")
        XCTAssertEqual(plan.sharedRecord?.payload.coupleSpaceId, "SPACE-1")
    }

    func testPlansSummarySharedRecordWithCanonicalPrivateCopyAndSanitizedSharedProjection() {
        let record = Record(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            type: .sleep,
            note: "醒了三次",
            tagsRaw: "poor,light",
            startAt: Date(timeIntervalSince1970: 5_000),
            endAt: Date(timeIntervalSince1970: 8_000),
            valueText: "5h",
            ownerUserId: "local",
            coupleSpaceId: "SPACE-1",
            visibility: .summaryShared,
            source: .manual,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 300),
            version: 4
        )

        let plan = CloudSyncRoutePlanner().plan(record: record)

        XCTAssertEqual(plan.privateRecord.scope, .private)
        XCTAssertEqual(plan.privateRecord.payload.note, "醒了三次")
        XCTAssertEqual(plan.privateRecord.payload.tags, ["poor", "light"])
        XCTAssertEqual(plan.privateRecord.payload.valueText, "5h")
        XCTAssertEqual(plan.sharedRecord?.scope, .shared)
        XCTAssertEqual(plan.sharedRecord?.payload.visibility, .summaryShared)
        XCTAssertEqual(plan.sharedRecord?.payload.summaryText, "已记录睡眠状态")
        XCTAssertNil(plan.sharedRecord?.payload.note)
        XCTAssertEqual(plan.sharedRecord?.payload.tags, [])
        XCTAssertNil(plan.sharedRecord?.payload.valueText)
    }

    func testPrivateVisibilityStaysInPrivateScopeOnly() {
        let record = Record(
            type: .water,
            note: "only me",
            startAt: Date(timeIntervalSince1970: 1_000),
            ownerUserId: "local",
            visibility: .private
        )

        let plan = CloudSyncRoutePlanner().plan(record: record)

        XCTAssertEqual(plan.privateRecord.scope, .private)
        XCTAssertNil(plan.sharedRecord)
    }

    func testSharedVisibilityFallsBackToPrivateOnlyWhenActiveCoupleSpaceDoesNotMatch() {
        let task = TaskItem(
            title: "旧空间任务",
            ownerUserId: "local",
            coupleSpaceId: "OLD-SPACE",
            visibility: .coupleShared
        )

        let plan = CloudSyncRoutePlanner().plan(task: task, activeCoupleSpaceId: "ACTIVE-SPACE")

        XCTAssertEqual(plan.privateRecord.scope, .private)
        XCTAssertNil(plan.sharedRecord)
    }
}
