import SwiftUI

struct ProfileTab: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("我的", systemImage: "person", description: Text("Phase 1 占位页面"))
                .navigationTitle("我的")
        }
    }
}
