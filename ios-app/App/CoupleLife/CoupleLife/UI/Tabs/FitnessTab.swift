import SwiftUI

struct FitnessTab: View {
    private let healthSnapshotRepository: any HealthSnapshotRepository
    private let healthDataService: any HealthDataService

    init(
        healthSnapshotRepository: any HealthSnapshotRepository,
        healthDataService: any HealthDataService
    ) {
        self.healthSnapshotRepository = healthSnapshotRepository
        self.healthDataService = healthDataService
    }

    var body: some View {
        NavigationStack {
            FitnessDashboardView(
                healthSnapshotRepository: healthSnapshotRepository,
                healthDataService: healthDataService
            )
        }
    }
}
