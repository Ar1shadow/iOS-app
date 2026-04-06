import XCTest
@testable import CoupleLife

final class FitnessDashboardChartAdapterTests: XCTestCase {
    func testMakeSeriesFillsMissingDailyBucketsForSevenDayWindow() {
        let calendar = Calendar(identifier: .gregorian)
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let today = calendar.startOfDay(for: referenceDate)
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: today)!

        let series = FitnessDashboardChartAdapter.makeSeries(
            bucket: .day,
            snapshots: [
                HealthMetricSnapshot(dayStart: fiveDaysAgo, ownerUserId: "u1", bucket: .day, steps: 4200),
                HealthMetricSnapshot(dayStart: twoDaysAgo, ownerUserId: "u1", bucket: .day, steps: 8600)
            ],
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(series.count, 7)
        XCTAssertEqual(series.first?.date, calendar.date(byAdding: .day, value: -6, to: today))
        XCTAssertEqual(series.last?.date, today)
        XCTAssertEqual(series.map(\.value), [nil, 4200, nil, nil, 8600, nil, nil])
    }
}
