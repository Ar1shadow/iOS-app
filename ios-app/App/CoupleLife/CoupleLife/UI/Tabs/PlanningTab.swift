import SwiftUI

struct PlanningTab: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("计划", systemImage: "checklist", description: Text("Phase 1 占位页面"))
                .navigationTitle("计划")
        }
    }
}
