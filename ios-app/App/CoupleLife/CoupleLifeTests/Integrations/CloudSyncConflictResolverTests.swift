import XCTest
@testable import CoupleLife

final class CloudSyncConflictResolverTests: XCTestCase {
    func testHigherVersionWinsForCanonicalTaskConflict() {
        let local = CloudSyncTaskPayload(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            title: "旧标题",
            detail: "local",
            startAt: nil,
            dueAt: nil,
            isAllDay: false,
            priority: 0,
            status: .todo,
            planLevel: .day,
            ownerUserId: "local",
            coupleSpaceId: "SPACE-1",
            visibility: .coupleShared,
            source: .manual,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200),
            version: 2
        )
        let remote = CloudSyncTaskPayload(
            id: local.id,
            title: "新标题",
            detail: "remote",
            startAt: nil,
            dueAt: nil,
            isAllDay: false,
            priority: 0,
            status: .todo,
            planLevel: .day,
            ownerUserId: "local",
            coupleSpaceId: "SPACE-1",
            visibility: .coupleShared,
            source: .manual,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 150),
            version: 3
        )

        let resolved = CloudSyncConflictResolver().resolveCanonicalTask(local: local, remote: remote)

        XCTAssertEqual(resolved.winner, remote)
        XCTAssertEqual(resolved.reason, .higherVersion)
    }

    func testNewerUpdatedAtWinsWhenVersionsMatch() {
        let local = CloudSyncRecordPayload(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            type: .water,
            summaryText: nil,
            note: "old",
            tags: [],
            valueText: "200ml",
            startAt: Date(timeIntervalSince1970: 1_000),
            endAt: nil,
            ownerUserId: "local",
            coupleSpaceId: nil,
            visibility: .private,
            source: .manual,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200),
            version: 2
        )
        let remote = CloudSyncRecordPayload(
            id: local.id,
            type: .water,
            summaryText: nil,
            note: "new",
            tags: [],
            valueText: "300ml",
            startAt: local.startAt,
            endAt: nil,
            ownerUserId: "local",
            coupleSpaceId: nil,
            visibility: .private,
            source: .manual,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 300),
            version: 2
        )

        let resolved = CloudSyncConflictResolver().resolveCanonicalRecord(local: local, remote: remote)

        XCTAssertEqual(resolved.winner, remote)
        XCTAssertEqual(resolved.reason, .newerTimestamp)
    }

    func testSharedProjectionNeverOverridesCanonicalPrivateDetail() {
        let canonical = CloudSyncRecordPayload(
            id: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!,
            type: .sleep,
            summaryText: nil,
            note: "醒了三次",
            tags: ["poor"],
            valueText: "5h",
            startAt: Date(timeIntervalSince1970: 1_000),
            endAt: Date(timeIntervalSince1970: 2_000),
            ownerUserId: "local",
            coupleSpaceId: "SPACE-1",
            visibility: .summaryShared,
            source: .manual,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200),
            version: 3
        )
        let sharedProjection = CloudSyncRecordPayload(
            id: canonical.id,
            type: .sleep,
            summaryText: "已记录睡眠状态",
            note: nil,
            tags: [],
            valueText: nil,
            startAt: canonical.startAt,
            endAt: canonical.endAt,
            ownerUserId: "local",
            coupleSpaceId: "SPACE-1",
            visibility: .summaryShared,
            source: .manual,
            createdAt: canonical.createdAt,
            updatedAt: Date(timeIntervalSince1970: 500),
            version: 99
        )

        let resolved = CloudSyncConflictResolver().resolveCanonicalRecord(
            local: canonical,
            remote: sharedProjection,
            remoteScope: .shared
        )

        XCTAssertEqual(resolved.winner, canonical)
        XCTAssertEqual(resolved.reason, .preservedCanonicalDetail)
    }
}
