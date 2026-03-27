import SwiftUI

struct HomeTab: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("首页", systemImage: "house", description: Text("Phase 1 占位页面"))
                .navigationTitle("首页")
        }
    }
}
