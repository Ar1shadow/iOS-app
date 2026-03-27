import XCTest
@testable import CoupleLife

final class AppTabTests: XCTestCase {
    func testAllTabsMatchPhaseOneInformationArchitecture() {
        XCTAssertEqual(AppTab.allCases.count, 5)
        XCTAssertEqual(AppTab.allCases.map(\.title), ["首页", "日历", "计划", "运动", "我的"])
        XCTAssertEqual(AppTab.allCases.map(\.systemImage), ["house", "calendar", "checklist", "figure.walk", "person"])
    }
}
