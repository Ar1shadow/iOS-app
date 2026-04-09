import XCTest
@testable import CoupleLife

final class VisibilityPolicyTests: XCTestCase {
    func testSensitiveRecordTypesAllowSummarySharing() {
        XCTAssertEqual(
            VisibilityPolicy.record(type: .menstruation).allowedVisibilities,
            [.private, .summaryShared, .coupleShared]
        )
        XCTAssertEqual(
            VisibilityPolicy.record(type: .bowelMovement).allowedVisibilities,
            [.private, .summaryShared, .coupleShared]
        )
        XCTAssertEqual(
            VisibilityPolicy.record(type: .sleep).allowedVisibilities,
            [.private, .summaryShared, .coupleShared]
        )
    }

    func testNonSensitiveRecordTypesAllowOnlyPrivateOrFullSharing() {
        XCTAssertEqual(
            VisibilityPolicy.record(type: .water).allowedVisibilities,
            [.private, .coupleShared]
        )
        XCTAssertEqual(
            VisibilityPolicy.record(type: .activity).allowedVisibilities,
            [.private, .coupleShared]
        )
    }

    func testTaskPolicyAllowsOnlyPrivateOrCoupleShared() {
        XCTAssertEqual(
            VisibilityPolicy.task.allowedVisibilities,
            [.private, .coupleShared]
        )
    }

    func testPolicySanitizesUnsupportedVisibilityToPrivate() {
        XCTAssertEqual(
            VisibilityPolicy.record(type: .water).sanitized(.summaryShared),
            .private
        )
        XCTAssertEqual(
            VisibilityPolicy.task.sanitized(.summaryShared),
            .private
        )
    }

    func testSummarySharedRecordContentDropsDetailedFields() {
        let content = VisibilityPolicy.record(type: .sleep).sharedRecordContent(
            visibility: .summaryShared,
            note: "昨晚醒来两次",
            tagsRaw: "wearable,manual",
            valueText: "6.5h"
        )

        XCTAssertEqual(content.visibility, .summaryShared)
        XCTAssertEqual(content.summaryText, "已记录睡眠状态")
        XCTAssertNil(content.note)
        XCTAssertTrue(content.tags.isEmpty)
        XCTAssertNil(content.valueText)
    }

    func testCoupleSharedRecordContentKeepsDetailedFields() {
        let content = VisibilityPolicy.record(type: .sleep).sharedRecordContent(
            visibility: .coupleShared,
            note: "昨晚醒来两次",
            tagsRaw: "wearable,manual",
            valueText: "6.5h"
        )

        XCTAssertEqual(content.visibility, .coupleShared)
        XCTAssertEqual(content.summaryText, "已记录睡眠状态")
        XCTAssertEqual(content.note, "昨晚醒来两次")
        XCTAssertEqual(content.tags, ["wearable", "manual"])
        XCTAssertEqual(content.valueText, "6.5h")
    }
}
