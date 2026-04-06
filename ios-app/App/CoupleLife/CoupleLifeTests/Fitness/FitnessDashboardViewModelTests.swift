import XCTest
@testable import CoupleLife

@MainActor
final class FitnessDashboardViewModelTests: XCTestCase {
    func testSelectBucketUpdatesVisibleContentWithoutRefreshingHealthData() async {
        let content = makeContent(needsBackgroundRefresh: false)
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
        let staleContent = makeContent(needsBackgroundRefresh: true, daySteps: 1234)
        let refreshedContent = makeContent(needsBackgroundRefresh: false, daySteps: 5678)
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

    func testRefreshHealthDataRetriesAvailabilityCheckWhenCurrentStateIsFailed() async {
        let content = makeContent(needsBackgroundRefresh: false)
        let refreshedContent = makeContent(needsBackgroundRefresh: false, daySteps: 9876)
        let service = StubFitnessDashboardService(contents: [content, refreshedContent])
        let healthService = StubFitnessHealthDataService(
            availabilitySequence: [.failed("x"), .available],
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
        await viewModel.refreshHealthData()

        XCTAssertEqual(healthService.availabilityCallCount, 2)
        XCTAssertEqual(healthService.refreshCallCount, 1)
        XCTAssertEqual(viewModel.visibleSummary?.steps, 9876)
    }

    func testRefreshHealthDataDoesNotRetryAvailabilityWhenCurrentStateIsNotAuthorized() async {
        let content = makeContent(needsBackgroundRefresh: false)
        let refreshedContent = makeContent(needsBackgroundRefresh: false, daySteps: 4321)
        let service = StubFitnessDashboardService(contents: [content, refreshedContent])
        let healthService = StubFitnessHealthDataService(
            availabilitySequence: [.notAuthorized],
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
        await viewModel.refreshHealthData()

        XCTAssertEqual(healthService.availabilityCallCount, 1)
        XCTAssertEqual(healthService.refreshCallCount, 0)
        XCTAssertEqual(viewModel.visibleSummary?.steps, 4321)
    }

    func testLoadShowsExpandedAvailableMessageWhenAllMetricsAreMissing() async {
        let content = makeEmptyContent(needsBackgroundRefresh: false)
        let service = StubFitnessDashboardService(contents: [content])
        let healthService = StubFitnessHealthDataService(
            availabilitySequence: [.available],
            requestAuthorizationAvailability: .available,
            refreshAvailability: .available
        )
        let viewModel = FitnessDashboardViewModel(
            service: service,
            healthDataService: healthService,
            ownerUserId: "u1"
        )

        await viewModel.load()

        guard case .loaded(let healthState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }

        XCTAssertEqual(
            healthState.message,
            "已连接健康服务。若暂无缓存，请确认系统健康权限已开放步数、距离、能量、运动、站立、睡眠和静息心率读取后手动刷新。"
        )
    }

    func testLoadShowsExpandedAuthorizationMessageWhenNotAuthorized() async {
        let content = makeContent(needsBackgroundRefresh: false)
        let service = StubFitnessDashboardService(contents: [content])
        let healthService = StubFitnessHealthDataService(
            availabilitySequence: [.notAuthorized],
            requestAuthorizationAvailability: .notAuthorized,
            refreshAvailability: .notAuthorized
        )
        let viewModel = FitnessDashboardViewModel(
            service: service,
            healthDataService: healthService,
            ownerUserId: "u1"
        )

        await viewModel.load()

        guard case .loaded(let healthState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }

        XCTAssertEqual(
            healthState.message,
            "未授权。请点按“连接健康数据”，随后在系统健康权限页开启步数、距离、能量、运动、站立、睡眠与心率读取。"
        )
    }

    private func makeContent(
        needsBackgroundRefresh: Bool,
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
            needsBackgroundRefresh: needsBackgroundRefresh
        )
    }

    private func makeEmptyContent(needsBackgroundRefresh: Bool) -> FitnessDashboardContent {
        let dayStart = Date(timeIntervalSince1970: 1_699_977_600)
        let weekStart = Date(timeIntervalSince1970: 1_699_459_200)
        let monthStart = Date(timeIntervalSince1970: 1_698_796_800)

        return FitnessDashboardContent(
            summaries: [
                .day: HealthMetricSnapshot(dayStart: dayStart, ownerUserId: "u1", bucket: .day),
                .week: HealthMetricSnapshot(dayStart: weekStart, ownerUserId: "u1", bucket: .week),
                .month: HealthMetricSnapshot(dayStart: monthStart, ownerUserId: "u1", bucket: .month)
            ],
            trendSeries: [.day: [], .week: [], .month: []],
            needsBackgroundRefresh: needsBackgroundRefresh
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
    private(set) var availabilityCallCount = 0

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
        availabilityCallCount += 1
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
