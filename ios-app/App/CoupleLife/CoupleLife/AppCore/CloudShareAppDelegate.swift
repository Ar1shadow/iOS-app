import Foundation
import UIKit

#if canImport(CloudKit)
import CloudKit
#endif

final class CloudShareAppDelegate: NSObject, UIApplicationDelegate {
    #if canImport(CloudKit)
    @available(iOS, deprecated: 26.0)
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        guard let url = cloudKitShareMetadata.share.url else { return }
        NotificationCenter.default.post(
            name: CloudShareNotifications.inviteURLReceived,
            object: nil,
            userInfo: [CloudShareNotifications.inviteURLUserInfoKey: url]
        )
    }
    #endif
}
