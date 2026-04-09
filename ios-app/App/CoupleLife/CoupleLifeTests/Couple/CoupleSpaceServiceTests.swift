import SwiftData
import XCTest
@testable import CoupleLife

final class CoupleSpaceServiceTests: XCTestCase {
    func testCreateSpaceCreatesOwnerMembershipAndActivatesSpace() throws {
        let harness = try makeHarness()
        let anniversaryDate = Date(timeIntervalSince1970: 1_700_000_000)
        let now = Date(timeIntervalSince1970: 1_700_086_400)
        let service = DefaultCoupleSpaceService(
            coupleSpaceRepository: harness.coupleSpaceRepository,
            membershipRepository: harness.membershipRepository,
            activeCoupleSpaceStore: harness.activeCoupleSpaceStore,
            saveChanges: harness.saveChanges,
            currentUserId: "local",
            idGenerator: { "SPACE123" },
            nowProvider: { now }
        )

        let status = try service.createSpace(
            name: "我们的小家",
            anniversaryDate: anniversaryDate
        )

        XCTAssertEqual(
            status,
            CoupleSpaceStatus(
                activeSpace: ActiveCoupleSpace(
                    id: "SPACE123",
                    name: "我们的小家",
                    anniversaryDate: anniversaryDate,
                    membershipRole: .owner,
                    joinedAt: now
                )
            )
        )
        XCTAssertEqual(harness.activeCoupleSpaceStore.activeCoupleSpaceId, "SPACE123")
        XCTAssertEqual(try harness.coupleSpaceRepository.fetch(id: "SPACE123")?.name, "我们的小家")
        XCTAssertEqual(
            try harness.membershipRepository.membership(coupleSpaceId: "SPACE123", userId: "local")?.role,
            .owner
        )
    }

    func testJoinExistingSpaceCreatesMemberMembershipAndActivatesSpace() throws {
        let harness = try makeHarness()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let joinedAt = Date(timeIntervalSince1970: 1_700_003_600)
        try harness.coupleSpaceRepository.create(
            CoupleSpace(
                id: "JOIN123",
                name: "远程演示空间",
                anniversaryDate: nil,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        )
        try harness.saveChanges()
        let service = DefaultCoupleSpaceService(
            coupleSpaceRepository: harness.coupleSpaceRepository,
            membershipRepository: harness.membershipRepository,
            activeCoupleSpaceStore: harness.activeCoupleSpaceStore,
            saveChanges: harness.saveChanges,
            currentUserId: "local",
            nowProvider: { joinedAt }
        )

        let status = try service.joinSpace(id: " join123 ")

        XCTAssertEqual(status.activeSpace?.id, "JOIN123")
        XCTAssertEqual(status.activeSpace?.membershipRole, .member)
        XCTAssertEqual(status.activeSpace?.joinedAt, joinedAt)
        XCTAssertEqual(harness.activeCoupleSpaceStore.activeCoupleSpaceId, "JOIN123")
        XCTAssertEqual(
            try harness.membershipRepository.membership(coupleSpaceId: "JOIN123", userId: "local")?.role,
            .member
        )
    }

    func testLeaveActiveSpaceClearsStoreButKeepsMembershipForLocalDemo() throws {
        let harness = try makeHarness()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try harness.coupleSpaceRepository.create(
            CoupleSpace(
                id: "SPACE123",
                name: "保留空间",
                anniversaryDate: nil,
                createdAt: now,
                updatedAt: now
            )
        )
        try harness.membershipRepository.create(
            Membership(
                coupleSpaceId: "SPACE123",
                userId: "local",
                role: .owner,
                joinedAt: now,
                createdAt: now,
                updatedAt: now
            )
        )
        try harness.saveChanges()
        harness.activeCoupleSpaceStore.activeCoupleSpaceId = "SPACE123"
        let service = DefaultCoupleSpaceService(
            coupleSpaceRepository: harness.coupleSpaceRepository,
            membershipRepository: harness.membershipRepository,
            activeCoupleSpaceStore: harness.activeCoupleSpaceStore,
            saveChanges: harness.saveChanges,
            currentUserId: "local",
            nowProvider: { now }
        )

        let status = try service.leaveActiveSpace()

        XCTAssertFalse(status.hasActiveSpace)
        XCTAssertNil(harness.activeCoupleSpaceStore.activeCoupleSpaceId)
        XCTAssertNotNil(try harness.membershipRepository.membership(coupleSpaceId: "SPACE123", userId: "local"))
        XCTAssertEqual(try harness.coupleSpaceRepository.fetch(id: "SPACE123")?.name, "保留空间")
    }

    func testLeaveThenJoinPreservesExistingRole() throws {
        let harness = try makeHarness()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let service = DefaultCoupleSpaceService(
            coupleSpaceRepository: harness.coupleSpaceRepository,
            membershipRepository: harness.membershipRepository,
            activeCoupleSpaceStore: harness.activeCoupleSpaceStore,
            saveChanges: harness.saveChanges,
            currentUserId: "local",
            idGenerator: { "SPACE123" },
            nowProvider: { now }
        )

        _ = try service.createSpace(name: "我们的小家", anniversaryDate: nil)
        XCTAssertEqual(try service.currentStatus().activeSpace?.membershipRole, .owner)

        _ = try service.leaveActiveSpace()
        XCTAssertFalse(try service.currentStatus().hasActiveSpace)

        let status = try service.joinSpace(id: "SPACE123")

        XCTAssertEqual(status.activeSpace?.membershipRole, .owner)
    }

    func testCurrentStatusClearsDanglingActiveSpaceIdentifier() throws {
        let harness = try makeHarness()
        harness.activeCoupleSpaceStore.activeCoupleSpaceId = "MISSING"
        let service = DefaultCoupleSpaceService(
            coupleSpaceRepository: harness.coupleSpaceRepository,
            membershipRepository: harness.membershipRepository,
            activeCoupleSpaceStore: harness.activeCoupleSpaceStore,
            saveChanges: harness.saveChanges,
            currentUserId: "local"
        )

        let status = try service.currentStatus()

        XCTAssertEqual(status, CoupleSpaceStatus(activeSpace: nil))
        XCTAssertNil(harness.activeCoupleSpaceStore.activeCoupleSpaceId)
    }
}

private extension CoupleSpaceServiceTests {
    func makeHarness() throws -> CoupleSpaceTestHarness {
        let schema = Schema([
            Record.self,
            TaskItem.self,
            HealthMetricSnapshot.self,
            CoupleSpace.self,
            Membership.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        return CoupleSpaceTestHarness(
            coupleSpaceRepository: SwiftDataCoupleSpaceRepository(context: context),
            membershipRepository: SwiftDataMembershipRepository(context: context),
            activeCoupleSpaceStore: TestActiveCoupleSpaceStore(),
            saveChanges: { try context.save() }
        )
    }
}

private struct CoupleSpaceTestHarness {
    let coupleSpaceRepository: SwiftDataCoupleSpaceRepository
    let membershipRepository: SwiftDataMembershipRepository
    let activeCoupleSpaceStore: TestActiveCoupleSpaceStore
    let saveChanges: () throws -> Void
}

private final class TestActiveCoupleSpaceStore: ActiveCoupleSpaceStore {
    var activeCoupleSpaceId: String?
}
