import Foundation

@MainActor
final class HomeDashboardViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded(HomeDashboardSummary, ServiceAvailability)
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
            state = .loaded(summary, availability)
        } catch {
            state = .failed("首页摘要加载失败，请稍后重试。")
        }
    }
}
