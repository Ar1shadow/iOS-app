import XCTest
@testable import CoupleLife

@MainActor
final class FitnessDashboardViewModelTests: XCTestCase {
    func testSelectBucketUpdatesVisibleContentWithoutRefreshingHealthData() async {
        let content = makeContent(isCurrentDayCacheStale: false)
        let service = StubFitnessDashboardService(contents: [content])
        let healthService = StubFitnessHealthDataService(
            availabilitySequence: [.available],
            requestAuthorizationAvailability: .available,
            refreshAvailability: .available
        )
        let viewModel = FitnessDashboardViewModel(
            service: service,
            healthDataService: healthService,
            ownerUserId: "u1",
            nowProvider: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        await viewModel.load()
        viewModel.selectBucket(.week)

        XCTAssertEqual(viewModel.selectedBucket, .week)
        XCTAssertEqual(viewModel.visibleSummary?.bucket, .week)
        XCTAssertEqual(viewModel.visibleTrend.first?.value, 21_000)
        XCTAssertEqual(healthService.refreshCallCount, 0)
    }

    func testRefreshIfNeededUsesStaleCacheSignalToReloadDashboard() async {
        let staleContent = makeContent(isCurrentDayCacheStale: true, daySteps: 1234)
        let refreshedContent = makeContent(isCurrentDayCacheStale: false, daySteps: 5678)
        let service = StubFitnessDashboardService(contents: [staleContent, refreshedContent])
        let healthService = StubFitnessHealthDataService(
            availabilitySequence: [.available],
            requestAuthorizationAvailability: .available,
            refreshAvailability: .available
        )
        let viewModel = FitnessDashboardViewModel(
            service: service,
            healthDataService: healthService,
            ownerUserId: "u1",
            nowProvider: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        await viewModel.load()
        await viewModel.refreshIfNeeded()

        XCTAssertEqual(healthService.refreshCallCount, 1)
        XCTAssertEqual(service.loadCallCount, 2)
        XCTAssertEqual(viewModel.visibleSummary?.steps, 5678)
    }

    private func makeContent(
        isCurrentDayCacheStale: Bool,
        daySteps: Double = 4321
    ) -> FitnessDashboardContent {
        let dayStart = Date(timeIntervalSince1970: 1_699_977_600)
        let weekStart = Date(timeIntervalSince1970: 1_699_459_200)
        let monthStart = Date(timeIntervalSince1970: 1_698_796_800)

        return FitnessDashboardContent(
            summaries: [
                .day: HealthMetricSnapshot(dayStart: dayStart, ownerUserId: "u1", bucket: .day, steps: daySteps),
                .week: HealthMetricSnapshot(dayStart: weekStart, ownerUserId: "u1", bucket: .week, steps: 30_000),
                .month: HealthMetricSnapshot(dayStart: monthStart, ownerUserId: "u1", bucket: .month, steps: 120_000)
            ],
            trendSeries: [
                .day: [FitnessTrendPoint(date: dayStart, label: "4/1", value: daySteps)],
                .week: [FitnessTrendPoint(date: weekStart, label: "4/1", value: 21_000)],
                .month: [FitnessTrendPoint(date: monthStart, label: "4月", value: 100_000)]
            ],
            isCurrentDayCacheStale: isCurrentDayCacheStale
        )
    }
}

private final class StubFitnessDashboardService: FitnessDashboardService {
    private let contents: [FitnessDashboardContent]
    private(set) var loadCallCount = 0

    init(contents: [FitnessDashboardContent]) {
        self.contents = contents
    }

    func load(ownerUserId: String, asOf date: Date) throws -> FitnessDashboardContent {
        let index = min(loadCallCount, contents.count - 1)
        defer { loadCallCount += 1 }
        return contents[index]
    }
}

private final class StubFitnessHealthDataService: HealthDataService {
    private let availabilitySequence: [ServiceAvailability]
    private let requestAuthorizationAvailability: ServiceAvailability
    private let refreshAvailability: ServiceAvailability
    private var availabilityIndex = 0

    private(set) var requestAuthorizationCallCount = 0
    private(set) var refreshCallCount = 0

    init(
        availabilitySequence: [ServiceAvailability],
        requestAuthorizationAvailability: ServiceAvailability,
        refreshAvailability: ServiceAvailability
    ) {
        self.availabilitySequence = availabilitySequence
        self.requestAuthorizationAvailability = requestAuthorizationAvailability
        self.refreshAvailability = refreshAvailability
    }

    func availability() async -> ServiceAvailability {
        let index = min(availabilityIndex, availabilitySequence.count - 1)
        defer { availabilityIndex += 1 }
        return availabilitySequence[index]
    }

    func requestAuthorization() async -> ServiceAvailability {
        requestAuthorizationCallCount += 1
        return requestAuthorizationAvailability
    }

    func refreshTodaySnapshot(ownerUserId: String, asOf date: Date, force: Bool) async -> ServiceAvailability {
        refreshCallCount += 1
        return refreshAvailability
    }
}
