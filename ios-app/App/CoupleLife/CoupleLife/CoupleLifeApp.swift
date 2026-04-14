import SwiftUI
import SwiftData

struct CoupleLifeRootView: View {
    let appContainer: AppContainer
    let modelContainer: ModelContainer

    var body: some View {
        RootTabView()
            .environment(\.appContainer, appContainer)
            .environment(\.modelContext, modelContainer.mainContext)
    }
}
