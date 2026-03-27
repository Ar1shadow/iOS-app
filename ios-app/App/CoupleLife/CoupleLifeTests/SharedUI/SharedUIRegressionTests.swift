import SwiftUI
import XCTest
@testable import CoupleLife

final class SharedUIRegressionTests: XCTestCase {
    func testSharedListRowUsesStackedLayoutForAccessibilitySizes() {
        XCTAssertEqual(SharedListRow.layoutMode(for: .large), .horizontal)
        XCTAssertEqual(SharedListRow.layoutMode(for: .accessibility1), .stacked)
        XCTAssertEqual(SharedListRow.layoutMode(for: .accessibility5), .stacked)
    }
}
