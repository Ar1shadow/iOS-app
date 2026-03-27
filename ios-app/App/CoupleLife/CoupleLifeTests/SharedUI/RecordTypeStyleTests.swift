import XCTest
@testable import CoupleLife

final class RecordTypeStyleTests: XCTestCase {
    func testEveryRecordTypeHasStableVisualStyle() {
        XCTAssertEqual(RecordType.water.visualStyle.title, "喝水")
        XCTAssertEqual(RecordType.water.visualStyle.symbolName, "drop.fill")
        XCTAssertEqual(RecordType.water.visualStyle.colorToken, .blue)

        XCTAssertEqual(RecordType.bowelMovement.visualStyle.title, "排便")
        XCTAssertEqual(RecordType.bowelMovement.visualStyle.symbolName, "toilet.fill")
        XCTAssertEqual(RecordType.bowelMovement.visualStyle.colorToken, .brown)

        XCTAssertEqual(RecordType.menstruation.visualStyle.title, "经期")
        XCTAssertEqual(RecordType.menstruation.visualStyle.symbolName, "drop.circle.fill")
        XCTAssertEqual(RecordType.menstruation.visualStyle.colorToken, .red)

        XCTAssertEqual(RecordType.sleep.visualStyle.title, "睡眠")
        XCTAssertEqual(RecordType.sleep.visualStyle.symbolName, "moon.stars.fill")
        XCTAssertEqual(RecordType.sleep.visualStyle.colorToken, .indigo)

        XCTAssertEqual(RecordType.activity.visualStyle.title, "活动")
        XCTAssertEqual(RecordType.activity.visualStyle.symbolName, "figure.walk")
        XCTAssertEqual(RecordType.activity.visualStyle.colorToken, .green)

        XCTAssertEqual(RecordType.custom.visualStyle.title, "自定义")
        XCTAssertEqual(RecordType.custom.visualStyle.symbolName, "square.and.pencil")
        XCTAssertEqual(RecordType.custom.visualStyle.colorToken, .slate)
    }

    func testVisualStylesCoverAllRecordTypes() {
        let mapped = Set(RecordTypeVisualCatalog.mapping.keys)
        XCTAssertEqual(mapped, Set(RecordType.allCases))
    }
}
