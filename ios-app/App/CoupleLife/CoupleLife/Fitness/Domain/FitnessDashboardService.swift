import Foundation

struct FitnessTrendPoint: Equatable {
    let date: Date
    let label: String
    let value: Double?
}

struct FitnessDashboardContent: Equatable {
    let summaries: [HealthMetricBucket: HealthMetricSnapshot]
    let trendSeries: [HealthMetricBucket: [FitnessTrendPoint]]
    let isCurrentDayCacheStale: Bool
}

protocol FitnessDashboardService {
    func load(ownerUserId: String, asOf date: Date) throws -> FitnessDashboardContent
}

struct FitnessDashboardChartAdapter {
    static func makeSeries(
        bucket: HealthMetricBucket,
        snapshots: [HealthMetricSnapshot],
        referenceDate: Date,
        calendar: Calendar
    ) -> [FitnessTrendPoint] {
        let periods = expectedPeriods(for: bucket, referenceDate: referenceDate, calendar: calendar)
        let snapshotMap = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.dayStart, $0) })

        return periods.map { periodStart in
            let snapshot = snapshotMap[periodStart]
            return FitnessTrendPoint(
                date: periodStart,
                label: label(for: bucket, date: periodStart, calendar: calendar),
                value: snapshot?.steps
            )
        }
    }

    static func expectedPeriods(
        for bucket: HealthMetricBucket,
        referenceDate: Date,
        calendar: Calendar
    ) -> [Date] {
        let anchor = alignedStart(for: bucket, containing: referenceDate, calendar: calendar)

        switch bucket {
        case .day:
            return (-6 ... 0).compactMap { calendar.date(byAdding: .day, value: $0, to: anchor) }
        case .week:
            return (-7 ... 0).compactMap { calendar.date(byAdding: .weekOfYear, value: $0, to: anchor) }
        case .month:
            return (-5 ... 0).compactMap { calendar.date(byAdding: .month, value: $0, to: anchor) }
        }
    }

    static func alignedStart(
        for bucket: HealthMetricBucket,
        containing date: Date,
        calendar: Calendar
    ) -> Date {
        switch bucket {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        case .month:
            return calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        }
    }

    private static func label(
        for bucket: HealthMetricBucket,
        date: Date,
        calendar: Calendar
    ) -> String {
        switch bucket {
        case .day, .week:
            return dayLabelFormatter(calendar: calendar).string(from: date)
        case .month:
            return monthLabelFormatter(calendar: calendar).string(from: date)
        }
    }

    private static func dayLabelFormatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        return formatter
    }

    private static func monthLabelFormatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月"
        return formatter
    }
}

final class DefaultFitnessDashboardService: FitnessDashboardService {
    private let repository: any HealthSnapshotRepository
    private let calendar: Calendar
    private let nowProvider: () -> Date

    init(
        repository: any HealthSnapshotRepository,
        calendar: Calendar = .current,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    func load(ownerUserId: String, asOf date: Date) throws -> FitnessDashboardContent {
        var summaries: [HealthMetricBucket: HealthMetricSnapshot] = [:]
        var trendSeries: [HealthMetricBucket: [FitnessTrendPoint]] = [:]

        for bucket in HealthMetricBucket.allCases {
            let currentStart = FitnessDashboardChartAdapter.alignedStart(for: bucket, containing: date, calendar: calendar)
            summaries[bucket] = try repository.snapshot(bucket: bucket, start: currentStart, ownerUserId: ownerUserId)

            let periods = FitnessDashboardChartAdapter.expectedPeriods(for: bucket, referenceDate: date, calendar: calendar)
            guard let firstPeriod = periods.first,
                  let lastPeriod = periods.last,
                  let rangeEnd = endDate(for: bucket, start: lastPeriod) else {
                trendSeries[bucket] = []
                continue
            }

            let snapshots = try repository.snapshots(
                bucket: bucket,
                from: firstPeriod,
                to: rangeEnd,
                ownerUserId: ownerUserId
            )
            trendSeries[bucket] = FitnessDashboardChartAdapter.makeSeries(
                bucket: bucket,
                snapshots: snapshots,
                referenceDate: date,
                calendar: calendar
            )
        }

        let dayStart = calendar.startOfDay(for: date)
        let isCurrentDayCacheStale: Bool
        if let daySnapshot = summaries[.day] {
            isCurrentDayCacheStale = !(daySnapshot.dayStart == dayStart && calendar.isDate(daySnapshot.updatedAt, inSameDayAs: nowProvider()))
        } else {
            isCurrentDayCacheStale = true
        }

        return FitnessDashboardContent(
            summaries: summaries,
            trendSeries: trendSeries,
            isCurrentDayCacheStale: isCurrentDayCacheStale
        )
    }

    private func endDate(for bucket: HealthMetricBucket, start: Date) -> Date? {
        switch bucket {
        case .day:
            return calendar.date(byAdding: .day, value: 1, to: start)
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: start)
        case .month:
            return calendar.date(byAdding: .month, value: 1, to: start)
        }
    }
}
