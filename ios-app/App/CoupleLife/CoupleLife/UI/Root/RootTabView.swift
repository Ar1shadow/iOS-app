import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appContainer) private var appContainer

    var body: some View {
        let taskRepository = SwiftDataTaskRepository(context: modelContext)
        let recordRepository = SwiftDataRecordRepository(context: modelContext)
        let healthSnapshotRepository = SwiftDataHealthSnapshotRepository(context: modelContext)

        TabView {
            HomeTab(
                taskRepository: taskRepository,
                recordRepository: recordRepository,
                healthSnapshotRepository: healthSnapshotRepository,
                healthDataService: appContainer.healthData
            )
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.systemImage) }

            CalendarTab(recordRepository: recordRepository)
                .tabItem { Label(AppTab.calendar.title, systemImage: AppTab.calendar.systemImage) }

            PlanningTab(
                taskRepository: taskRepository,
                calendarSyncService: appContainer.calendarSync,
                calendarSyncSettings: appContainer.calendarSyncSettings
            )
                .tabItem { Label(AppTab.planning.title, systemImage: AppTab.planning.systemImage) }

            FitnessTab()
                .tabItem { Label(AppTab.fitness.title, systemImage: AppTab.fitness.systemImage) }

            ProfileTab(
                healthDataService: appContainer.healthData,
                calendarSyncService: appContainer.calendarSync,
                calendarSyncSettings: appContainer.calendarSyncSettings,
                notificationScheduler: appContainer.notifications,
                cloudSyncService: appContainer.cloudSync
            )
                .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.systemImage) }
        }
    }
}
