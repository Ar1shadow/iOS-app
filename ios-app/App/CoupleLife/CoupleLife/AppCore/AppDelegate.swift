import UIKit
import SwiftData

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    let modelContainer: ModelContainer
    let appContainer: AppContainer

    override init() {
        do {
            let container = try ModelContainerFactory.make()
            self.modelContainer = container
            self.appContainer = AppContainer.live(modelContainer: container)
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
        super.init()
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

