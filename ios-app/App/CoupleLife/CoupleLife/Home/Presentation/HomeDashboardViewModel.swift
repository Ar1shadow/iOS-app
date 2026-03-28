import Foundation

@MainActor
final class HomeDashboardViewModel: ObservableObject {
    struct HealthState: Equatable {
        let availability: ServiceAvailability
        let isRefreshing: Bool
        let message: String?
    }

    enum State: Equatable {
        case loading
        case loaded(HomeDashboardSummary, HealthState)
        case failed(String)
    }

    @Published private(set) var state: State = .loading

    private let service: any HomeDashboardService
    private let healthDataService: any HealthDataService
    private let ownerUserId: String
    private let nowProvider: () -> Date

    init(
        service: any HomeDashboardService,
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
            // Let the loading state render before synchronous repo fetch work begins.
            await Task.yield()
            let summary = try service.load(for: nowProvider(), ownerUserId: ownerUserId)
            let availability = await healthDataService.availability()
            state = .loaded(summary, makeHealthState(summary: summary, availability: availability))
        } catch {
            state = .failed("首页摘要加载失败，请稍后重试。")
        }
    }

    func connectHealthData() async {
        await performHealthAction(requestAuthorization: true, forceRefresh: true)
    }

    func refreshHealthData() async {
        await performHealthAction(requestAuthorization: false, forceRefresh: true)
    }

    private func performHealthAction(requestAuthorization: Bool, forceRefresh: Bool) async {
        guard case .loaded(let currentSummary, let currentHealthState) = state else {
            return
        }

        state = .loaded(
            currentSummary,
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
            let summary = try service.load(for: nowProvider(), ownerUserId: ownerUserId)
            state = .loaded(summary, makeHealthState(summary: summary, availability: availability))
        } catch {
            state = .failed("首页摘要加载失败，请稍后重试。")
        }
    }

    private func makeHealthState(summary: HomeDashboardSummary, availability: ServiceAvailability) -> HealthState {
        HealthState(
            availability: availability,
            isRefreshing: false,
            message: message(for: availability, summary: summary)
        )
    }

    private func message(for availability: ServiceAvailability, summary: HomeDashboardSummary) -> String? {
        switch availability {
        case .available where summary.steps == nil && summary.sleepHours == nil:
            return "已连接健康服务。若看不到数据，请在系统健康权限中确认已允许读取步数/睡眠，并可手动刷新摘要。"
        case .available:
            return nil
        case .notAuthorized:
            return "未授权。请点按“连接健康数据”，随后在系统健康权限页开启步数与睡眠读取。"
        case .notSupported:
            return "当前设备或环境不支持 HealthKit。模拟器上也可能出现无数据。"
        case .failed(let message):
            return message
        }
    }
}
