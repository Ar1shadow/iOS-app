import SwiftUI

struct CalendarTab: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("日历", systemImage: "calendar", description: Text("Phase 1 占位页面"))
                .navigationTitle("日历")
        }
    }
}
