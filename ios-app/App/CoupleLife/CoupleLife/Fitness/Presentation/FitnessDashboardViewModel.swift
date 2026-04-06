import Foundation

@MainActor
final class FitnessDashboardViewModel: ObservableObject {
    struct HealthState: Equatable {
        let availability: ServiceAvailability
        let isRefreshing: Bool
        let message: String?
    }

    enum State: Equatable {
        case loading
        case loaded(HealthState)
        case failed(String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var selectedBucket: HealthMetricBucket = .day

    var visibleSummary: HealthMetricSnapshot? {
        content?.summaries[selectedBucket]
    }

    var visibleTrend: [FitnessTrendPoint] {
        content?.trendSeries[selectedBucket] ?? []
    }

    var hasAnyTrendData: Bool {
        visibleTrend.contains { $0.value != nil }
    }

    private let service: any FitnessDashboardService
    private let healthDataService: any HealthDataService
    private let ownerUserId: String
    private let nowProvider: () -> Date
    private var content: FitnessDashboardContent?

    init(
        service: any FitnessDashboardService,
        healthDataService: any HealthDataService,
        ownerUserId: String,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.service = service
        self.healthDataService = healthDataService
        self.ownerUserId = ownerUserId
        self.nowProvider = nowProvider
    }

    func load() async {
        state = .loading

        do {
            await Task.yield()
            let content = try service.load(ownerUserId: ownerUserId, asOf: nowProvider())
            let availability = await healthDataService.availability()
            self.content = content
            state = .loaded(makeHealthState(content: content, availability: availability, isRefreshing: false))
        } catch {
            state = .failed("运动仪表盘加载失败，请稍后重试。")
        }
    }

    func refreshIfNeeded() async {
        guard let content, content.isCurrentDayCacheStale else {
            return
        }

        await performHealthAction(requestAuthorization: false, forceRefresh: true)
    }

    func connectHealthData() async {
        await performHealthAction(requestAuthorization: true, forceRefresh: true)
    }

    func refreshHealthData() async {
        await performHealthAction(requestAuthorization: false, forceRefresh: true)
    }

    func selectBucket(_ bucket: HealthMetricBucket) {
        selectedBucket = bucket
    }

    private func performHealthAction(requestAuthorization: Bool, forceRefresh: Bool) async {
        guard case .loaded(let currentHealthState) = state else {
            return
        }

        state = .loaded(
            HealthState(
                availability: currentHealthState.availability,
                isRefreshing: true,
                message: currentHealthState.message
            )
        )

        var availability = currentHealthState.availability
        if requestAuthorization {
            availability = await healthDataService.requestAuthorization()
        }

        if availability == .available {
            availability = await healthDataService.refreshTodaySnapshot(
                ownerUserId: ownerUserId,
                asOf: nowProvider(),
                force: forceRefresh
            )
        }

        do {
            let content = try service.load(ownerUserId: ownerUserId, asOf: nowProvider())
            self.content = content
            state = .loaded(makeHealthState(content: content, availability: availability, isRefreshing: false))
        } catch {
            state = .failed("运动仪表盘加载失败，请稍后重试。")
        }
    }

    private func makeHealthState(
        content: FitnessDashboardContent,
        availability: ServiceAvailability,
        isRefreshing: Bool
    ) -> HealthState {
        HealthState(
            availability: availability,
            isRefreshing: isRefreshing,
            message: message(for: availability, content: content)
        )
    }

    private func message(for availability: ServiceAvailability, content: FitnessDashboardContent) -> String? {
        switch availability {
        case .available where content.summaries.values.allSatisfy({ $0.steps == nil && $0.sleepSeconds == nil && $0.restingHeartRate == nil }):
            return "已连接健康服务。若暂无步数、睡眠或静息心率，请确认系统健康权限后手动刷新缓存。"
        case .available:
            return nil
        case .notAuthorized:
            return "未授权。请点按“连接健康数据”，随后在系统健康权限页开启步数、睡眠与心率读取。"
        case .notSupported:
            return "当前设备或环境不支持 HealthKit，模拟器通常也不会返回真实健康数据。"
        case .failed(let message):
            return message
        }
    }
}
