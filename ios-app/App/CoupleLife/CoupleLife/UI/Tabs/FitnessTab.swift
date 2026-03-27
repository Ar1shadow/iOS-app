import SwiftUI

struct FitnessTab: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("运动", systemImage: "figure.walk", description: Text("Phase 1 占位页面"))
                .navigationTitle("运动")
        }
    }
}
