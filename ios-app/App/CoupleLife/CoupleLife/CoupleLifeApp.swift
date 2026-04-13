import SwiftUI
import SwiftData

@main
struct CoupleLifeApp: App {
    @UIApplicationDelegateAdaptor(CloudShareAppDelegate.self) private var appDelegate
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
                .onOpenURL { url in
                    NotificationCenter.default.post(
                        name: CloudShareNotifications.inviteURLReceived,
                        object: nil,
                        userInfo: [CloudShareNotifications.inviteURLUserInfoKey: url]
                    )
                }
                .onReceive(NotificationCenter.default.publisher(for: CloudShareNotifications.inviteURLReceived)) { notification in
                    guard
                        let url = notification.userInfo?[CloudShareNotifications.inviteURLUserInfoKey] as? URL
                    else {
                        return
                    }

                    Task {
                        _ = await container.cloudShareAcceptance.acceptShare(from: url)
                        NotificationCenter.default.post(name: CloudShareNotifications.acceptanceDidUpdate, object: nil)
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
