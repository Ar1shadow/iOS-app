import Foundation

enum CloudShareNotifications {
    static let inviteURLReceived = Notification.Name("CloudShareInviteURLReceived")
    static let acceptanceDidUpdate = Notification.Name("CloudShareAcceptanceDidUpdate")
    static let inviteURLUserInfoKey = "url"
}

