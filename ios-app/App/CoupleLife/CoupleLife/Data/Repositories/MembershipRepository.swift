import Foundation
import SwiftData

protocol MembershipRepository {
    func create(_ membership: Membership) throws
    func membership(coupleSpaceId: String, userId: String) throws -> Membership?
    func delete(_ membership: Membership) throws
}

final class SwiftDataMembershipRepository: MembershipRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func create(_ membership: Membership) throws {
        context.insert(membership)
    }

    func membership(coupleSpaceId: String, userId: String) throws -> Membership? {
        let predicate = #Predicate<Membership> {
            $0.coupleSpaceId == coupleSpaceId && $0.userId == userId
        }
        let descriptor = FetchDescriptor<Membership>(predicate: predicate)
        return try context.fetch(descriptor).first
    }

    func delete(_ membership: Membership) throws {
        context.delete(membership)
    }
}
