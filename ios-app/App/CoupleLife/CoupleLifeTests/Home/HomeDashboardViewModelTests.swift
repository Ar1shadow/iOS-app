import XCTest
@testable import CoupleLife

@MainActor
final class HomeDashboardViewModelTests: XCTestCase {
    func testConnectHealthDataRequestsAuthorizationRefreshesSnapshotAndReloadsSummary() async {
        let initialSummary = makeSummary(steps: nil, sleepHours: nil)
        let refreshedSummary = makeSummary(steps: 8123, sleepHours: 7.2)
        let dashboardService = StubHomeDashboardService(summaries: [initialSummary, refreshedSummary])
        let healthService = StubHealthDataService(
            availabilitySequence: [.notAuthorized, .available],
            requestAuthorizationAvailability: .available,
            refreshAvailability: .available
        )
        let viewModel = HomeDashboardViewModel(
            service: dashboardService,
            healthDataService: healthService,
            ownerUserId: "u1",
            nowProvider: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        await viewModel.load()
        await viewModel.connectHealthData()

        guard case .loaded(let summary, let healthState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }

        XCTAssertEqual(summary.steps, 8123)
        XCTAssertEqual(summary.sleepHours, 7.2)
        XCTAssertEqual(healthState.availability, .available)
        XCTAssertEqual(healthService.requestAuthorizationCallCount, 1)
        XCTAssertEqual(healthService.refreshCallCount, 1)
    }

    func testConnectHealthDataPreservesLoadedSummaryWhenAuthorizationRemainsDenied() async {
        let initialSummary = makeSummary(steps: nil, sleepHours: nil)
        let dashboardService = StubHomeDashboardService(summaries: [initialSummary])
        let healthService = StubHealthDataService(
            availabilitySequence: [.notAuthorized],
            requestAuthorizationAvailability: .notAuthorized,
            refreshAvailability: .available
        )
        let viewModel = HomeDashboardViewModel(
            service: dashboardService,
            healthDataService: healthService,
            ownerUserId: "u1",
            nowProvider: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        await viewModel.load()
        await viewModel.connectHealthData()

        guard case .loaded(let summary, let healthState) = viewModel.state else {
            return XCTFail("Expected loaded state")
        }

        XCTAssertNil(summary.steps)
        XCTAssertEqual(healthState.availability, .notAuthorized)
        XCTAssertEqual(healthService.requestAuthorizationCallCount, 1)
        XCTAssertEqual(healthService.refreshCallCount, 0)
        XCTAssertFalse(healthState.isRefreshing)
        XCTAssertNotNil(healthState.message)
    }

    private func makeSummary(steps: Int?, sleepHours: Double?) -> HomeDashboardSummary {
        HomeDashboardSummary(
            dayRange: DateInterval(
                start: Date(timeIntervalSince1970: 1_700_000_000),
                end: Date(timeIntervalSince1970: 1_700_003_600)
            ),
            todayTaskTotal: 0,
            todayTaskCompleted: 0,
            todayRecordTotal: 0,
            recordTypeCounts: [:],
            importantEvents: [],
            weeklyInsight: HomeDashboardWeeklyInsight(
                weekRange: DateInterval(
                    start: Date(timeIntervalSince1970: 1_699_660_800),
                    end: Date(timeIntervalSince1970: 1_700_265_600)
                ),
                totalTaskCount: 0,
                completedTaskCount: 0,
                recordCount: 0,
                activeDayCount: 0,
                dominantRecordType: nil,
                totalSteps: nil,
                averageSleepHours: nil
            ),
            steps: steps,
            sleepHours: sleepHours
        )
    }
}

private final class StubHomeDashboardService: HomeDashboardService {
    private let summaries: [HomeDashboardSummary]
    private var loadCount = 0

    init(summaries: [HomeDashboardSummary]) {
        self.summaries = summaries
    }

    func load(for day: Date, ownerUserId: String) throws -> HomeDashboardSummary {
        let index = min(loadCount, summaries.count - 1)
        defer { loadCount += 1 }
        return summaries[index]
    }
}

private final class StubHealthDataService: HealthDataService {
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
