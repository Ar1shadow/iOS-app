import SwiftUI
import XCTest
@testable import CoupleLife

final class SharedUIRegressionTests: XCTestCase {
    func testHomeTabUsesExplicitShowcaseDisclaimer() {
        XCTAssertEqual(HomeTab.showcaseSectionTitle, "SharedUI 组件展示")
        XCTAssertEqual(HomeTab.showcaseSectionSubtitle, "静态占位展示，不代表真实记录数据")
    }

    func testSharedListRowUsesStackedLayoutForAccessibilitySizes() {
        XCTAssertEqual(SharedListRow.layoutMode(for: .large), .horizontal)
        XCTAssertEqual(SharedListRow.layoutMode(for: .accessibility1), .stacked)
        XCTAssertEqual(SharedListRow.layoutMode(for: .accessibility5), .stacked)
    }
}
