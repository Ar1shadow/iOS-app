import SwiftUI
import SwiftData

@main
struct CoupleLifeApp: App {
    private let container: AppContainer
    private let modelContainer: ModelContainer

    @MainActor
    init() {
        do {
            modelContainer = try ModelContainerFactory.make()
            container = AppContainer.live(modelContainer: modelContainer)
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.appContainer, container)
        }
        .modelContainer(modelContainer)
    }
}
