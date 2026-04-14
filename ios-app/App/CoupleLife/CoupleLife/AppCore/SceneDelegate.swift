import UIKit
import SwiftUI

#if canImport(CloudKit)
import CloudKit
#endif

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        let rootView = CoupleLifeRootView(
            appContainer: appDelegate.appContainer,
            modelContainer: appDelegate.modelContainer
        )

        let hostingController = UIHostingController(rootView: rootView)
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = hostingController
        self.window = window
        window.makeKeyAndVisible()

        handleConnectionOptions(connectionOptions, appContainer: appDelegate.appContainer)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        for context in URLContexts {
            acceptShareURL(context.url, appContainer: appDelegate.appContainer)
        }
    }

    #if canImport(CloudKit)
    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        acceptShareMetadata(cloudKitShareMetadata, appContainer: appDelegate.appContainer)
    }
    #endif
}

private extension SceneDelegate {
    func handleConnectionOptions(
        _ options: UIScene.ConnectionOptions,
        appContainer: AppContainer
    ) {
        for context in options.urlContexts {
            acceptShareURL(context.url, appContainer: appContainer)
        }

        #if canImport(CloudKit)
        if let metadata = options.cloudKitShareMetadata {
            acceptShareMetadata(metadata, appContainer: appContainer)
        }
        #endif
    }

    func acceptShareURL(_ url: URL, appContainer: AppContainer) {
        Task {
            _ = await appContainer.cloudShareAcceptance.acceptShare(from: url)
            NotificationCenter.default.post(name: CloudShareNotifications.acceptanceDidUpdate, object: nil)
        }
    }

    #if canImport(CloudKit)
    func acceptShareMetadata(_ metadata: CKShare.Metadata, appContainer: AppContainer) {
        Task {
            _ = await appContainer.cloudShareAcceptance.acceptShare(from: metadata)
            NotificationCenter.default.post(name: CloudShareNotifications.acceptanceDidUpdate, object: nil)
        }
    }
    #endif
}

