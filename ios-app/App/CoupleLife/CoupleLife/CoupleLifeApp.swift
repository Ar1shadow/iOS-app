import SwiftUI
import SwiftData

@main
struct CoupleLifeApp: App {
    private let container = AppContainer.default
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainerFactory.make()
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
