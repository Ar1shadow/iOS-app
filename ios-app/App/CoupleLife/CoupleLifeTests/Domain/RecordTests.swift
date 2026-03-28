import XCTest
@testable import CoupleLife

final class RecordTests: XCTestCase {
    func testTagsExposeTrimmedCommaSeparatedValues() {
        let record = Record(
            type: .custom,
            note: nil,
            tagsRaw: " work , hydration, , sleep ",
            startAt: Date(timeIntervalSince1970: 0),
            ownerUserId: "u1"
        )

        XCTAssertEqual(record.tags, ["work", "hydration", "sleep"])
    }

    func testSettingTagsNormalizesStoredString() {
        let record = Record(
            type: .custom,
            note: nil,
            startAt: Date(timeIntervalSince1970: 0),
            ownerUserId: "u1"
        )

        record.tags = ["  travel  ", "", "home"]

        XCTAssertEqual(record.tagsRaw, "travel,home")
    }

    func testNilTagsRawBehavesLikeEmptyTags() {
        let record = Record(
            type: .custom,
            note: nil,
            tagsRaw: nil,
            startAt: Date(timeIntervalSince1970: 0),
            ownerUserId: "u1"
        )

        XCTAssertTrue(record.tags.isEmpty)
        XCTAssertNil(record.tagsRaw)
    }
}
