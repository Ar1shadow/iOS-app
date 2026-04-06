import Foundation

struct ActiveCoupleSpace: Equatable {
    let id: String
    let name: String
    let anniversaryDate: Date?
    let membershipRole: MembershipRole
    let joinedAt: Date
}

struct CoupleSpaceStatus: Equatable {
    let activeSpace: ActiveCoupleSpace?

    var hasActiveSpace: Bool {
        activeSpace != nil
    }
}

enum CoupleSpaceServiceError: LocalizedError, Equatable {
    case emptyName
    case emptySpaceID
    case spaceNotFound

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "请输入情侣空间名称。"
        case .emptySpaceID:
            return "请输入可分享的空间 ID。"
        case .spaceNotFound:
            return "未找到这个空间 ID。请确认对方分享的是当前设备上的本地演示空间。"
        }
    }
}

protocol CoupleSpaceService {
    func currentStatus() throws -> CoupleSpaceStatus
    func createSpace(name: String, anniversaryDate: Date?) throws -> CoupleSpaceStatus
    func joinSpace(id: String) throws -> CoupleSpaceStatus
    func leaveActiveSpace() throws -> CoupleSpaceStatus
}

final class DefaultCoupleSpaceService: CoupleSpaceService {
    private let coupleSpaceRepository: any CoupleSpaceRepository
    private let membershipRepository: any MembershipRepository
    private let activeCoupleSpaceStore: any ActiveCoupleSpaceStore
    private let saveChanges: () throws -> Void
    private let currentUserId: String
    private let idGenerator: () -> String
    private let nowProvider: () -> Date

    init(
        coupleSpaceRepository: any CoupleSpaceRepository,
        membershipRepository: any MembershipRepository,
        activeCoupleSpaceStore: any ActiveCoupleSpaceStore,
        saveChanges: @escaping () throws -> Void,
        currentUserId: String = CurrentUser.id,
        idGenerator: @escaping () -> String = DefaultCoupleSpaceService.generateSpaceID,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.coupleSpaceRepository = coupleSpaceRepository
        self.membershipRepository = membershipRepository
        self.activeCoupleSpaceStore = activeCoupleSpaceStore
        self.saveChanges = saveChanges
        self.currentUserId = currentUserId
        self.idGenerator = idGenerator
        self.nowProvider = nowProvider
    }

    func currentStatus() throws -> CoupleSpaceStatus {
        guard let activeCoupleSpaceId = activeCoupleSpaceStore.activeCoupleSpaceId else {
            return CoupleSpaceStatus(activeSpace: nil)
        }

        guard let coupleSpace = try coupleSpaceRepository.fetch(id: activeCoupleSpaceId),
              let membership = try membershipRepository.membership(
                coupleSpaceId: activeCoupleSpaceId,
                userId: currentUserId
              ) else {
            activeCoupleSpaceStore.activeCoupleSpaceId = nil
            return CoupleSpaceStatus(activeSpace: nil)
        }

        return CoupleSpaceStatus(
            activeSpace: ActiveCoupleSpace(
                id: coupleSpace.id,
                name: coupleSpace.name,
                anniversaryDate: coupleSpace.anniversaryDate,
                membershipRole: membership.role,
                joinedAt: membership.joinedAt
            )
        )
    }

    func createSpace(name: String, anniversaryDate: Date?) throws -> CoupleSpaceStatus {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw CoupleSpaceServiceError.emptyName
        }

        let now = nowProvider()
        let coupleSpaceID = idGenerator()
        let coupleSpace = CoupleSpace(
            id: coupleSpaceID,
            name: trimmedName,
            anniversaryDate: anniversaryDate,
            createdAt: now,
            updatedAt: now
        )
        let membership = Membership(
            coupleSpaceId: coupleSpaceID,
            userId: currentUserId,
            role: .owner,
            joinedAt: now,
            createdAt: now,
            updatedAt: now
        )

        try coupleSpaceRepository.create(coupleSpace)
        try membershipRepository.create(membership)
        try saveChanges()
        activeCoupleSpaceStore.activeCoupleSpaceId = coupleSpaceID

        return try currentStatus()
    }

    func joinSpace(id: String) throws -> CoupleSpaceStatus {
        let normalizedID = id
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !normalizedID.isEmpty else {
            throw CoupleSpaceServiceError.emptySpaceID
        }

        guard let coupleSpace = try coupleSpaceRepository.fetch(id: normalizedID) else {
            throw CoupleSpaceServiceError.spaceNotFound
        }

        if try membershipRepository.membership(coupleSpaceId: normalizedID, userId: currentUserId) == nil {
            let now = nowProvider()
            try membershipRepository.create(
                Membership(
                    coupleSpaceId: normalizedID,
                    userId: currentUserId,
                    role: .member,
                    joinedAt: now,
                    createdAt: now,
                    updatedAt: now
                )
            )
            try saveChanges()
        }

        activeCoupleSpaceStore.activeCoupleSpaceId = coupleSpace.id
        return try currentStatus()
    }

    func leaveActiveSpace() throws -> CoupleSpaceStatus {
        guard activeCoupleSpaceStore.activeCoupleSpaceId != nil else {
            return CoupleSpaceStatus(activeSpace: nil)
        }
        activeCoupleSpaceStore.activeCoupleSpaceId = nil
        return CoupleSpaceStatus(activeSpace: nil)
    }

    private static func generateSpaceID() -> String {
        String(UUID().uuidString.prefix(8)).uppercased()
    }
}
