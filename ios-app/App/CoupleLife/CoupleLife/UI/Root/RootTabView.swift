import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeTab()
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.systemImage) }

            CalendarTab()
                .tabItem { Label(AppTab.calendar.title, systemImage: AppTab.calendar.systemImage) }

            PlanningTab()
                .tabItem { Label(AppTab.planning.title, systemImage: AppTab.planning.systemImage) }

            FitnessTab()
                .tabItem { Label(AppTab.fitness.title, systemImage: AppTab.fitness.systemImage) }

            ProfileTab()
                .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.systemImage) }
        }
    }
}
