import XCTest
@testable import CoupleLife

final class FitnessDashboardPresentationTests: XCTestCase {
    func testMetricDetailTextUsesCacheGuidanceWhenValueIsMissing() {
        let snapshot = HealthMetricSnapshot(dayStart: .distantPast, ownerUserId: "u1", bucket: .day)

        XCTAssertEqual(FitnessMetricCard.distance.detailText(from: snapshot), "暂无缓存，请授权并刷新。")
        XCTAssertEqual(FitnessMetricCard.activeEnergy.detailText(from: snapshot), "暂无缓存，请授权并刷新。")
        XCTAssertEqual(FitnessMetricCard.exercise.detailText(from: snapshot), "暂无缓存，请授权并刷新。")
        XCTAssertEqual(FitnessMetricCard.stand.detailText(from: snapshot), "暂无缓存，请授权并刷新。")
    }

    func testMetricDetailTextUsesAggregatedHealthCopyWhenValueExists() {
        let snapshot = HealthMetricSnapshot(
            dayStart: .distantPast,
            ownerUserId: "u1",
            bucket: .day,
            distanceMeters: 3200,
            activeEnergyKcal: 450,
            exerciseMinutes: 35,
            standMinutes: 600
        )

        XCTAssertEqual(FitnessMetricCard.distance.detailText(from: snapshot), "来自 Apple 健康的聚合数据")
        XCTAssertEqual(FitnessMetricCard.activeEnergy.detailText(from: snapshot), "来自 Apple 健康的聚合数据")
        XCTAssertEqual(FitnessMetricCard.exercise.detailText(from: snapshot), "来自 Apple 健康的聚合数据")
        XCTAssertEqual(FitnessMetricCard.stand.detailText(from: snapshot), "来自 Apple 健康的聚合数据")
    }

    func testChartMarksKeepMissingValuesOutOfBarSeries() {
        let points = [
            FitnessTrendPoint(date: Date(timeIntervalSince1970: 1), label: "4/1", value: 3200),
            FitnessTrendPoint(date: Date(timeIntervalSince1970: 2), label: "4/2", value: nil)
        ]

        let marks = FitnessTrendChartMark.make(for: points)

        XCTAssertEqual(marks.count, 2)
        XCTAssertEqual(marks[0], .value(date: Date(timeIntervalSince1970: 1), label: "4/1", value: 3200))
        XCTAssertEqual(marks[1], .missing(date: Date(timeIntervalSince1970: 2), label: "4/2"))
    }

    func testSourceMarkerUsesNoDataCopyWhenSnapshotIsMissing() {
        XCTAssertEqual(FitnessDashboardSourceMarker.text(for: nil), "暂无数据")
    }

    func testSourceMarkerUsesNoDataCopyWhenMetricValueIsMissing() {
        let snapshot = HealthMetricSnapshot(
            dayStart: .distantPast,
            ownerUserId: "u1",
            bucket: .day,
            source: .healthKit,
            steps: 3200
        )

        XCTAssertEqual(FitnessDashboardSourceMarker.text(for: snapshot, metric: .distance), "暂无数据")
    }

    func testSourceMarkerUsesSystemSyncWhenMetricValueExists() {
        let snapshot = HealthMetricSnapshot(
            dayStart: .distantPast,
            ownerUserId: "u1",
            bucket: .day,
            source: .healthKit,
            distanceMeters: 2400
        )

        XCTAssertEqual(FitnessDashboardSourceMarker.text(for: snapshot, metric: .distance), "系统同步")
    }
}
