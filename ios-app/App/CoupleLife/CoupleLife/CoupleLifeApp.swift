import SwiftUI

@main
struct CoupleLifeApp: App {
    private let container = AppContainer.default

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.appContainer, container)
        }
    }
}
