import Foundation
import SwiftData

enum MembershipRole: String, Codable, CaseIterable {
    case owner
    case member
}

@Model
final class Membership {
    @Attribute(.unique) var id: UUID

    var coupleSpaceId: String
    var userId: String
    var roleRaw: String
    var joinedAt: Date

    var createdAt: Date
    var updatedAt: Date
    var version: Int

    init(
        id: UUID = UUID(),
        coupleSpaceId: String,
        userId: String,
        role: MembershipRole,
        joinedAt: Date = Date(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1
    ) {
        self.id = id
        self.coupleSpaceId = coupleSpaceId
        self.userId = userId
        self.roleRaw = role.rawValue
        self.joinedAt = joinedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
    }

    var role: MembershipRole {
        get { MembershipRole(rawValue: roleRaw) ?? .member }
        set { roleRaw = newValue.rawValue }
    }
}
