import XCTest
@testable import CoupleLife

final class DefaultCloudSyncServiceTests: XCTestCase {
    func testRefreshPushesPrivateRecordsWhenNoActiveCoupleSpace() async {
        let task = TaskItem(
            title: "私有任务",
            ownerUserId: "local",
            coupleSpaceId: "SPACE-1",
            visibility: .coupleShared
        )
        let client = TestCloudSyncClient(accountAvailability: .available)
        let service = DefaultCloudSyncService(
            client: client,
            taskSource: StubCloudSyncTaskSource(tasks: [task]),
            recordSource: StubCloudSyncRecordSource(records: []),
            taskSink: StubCloudSyncTaskSink(),
            recordSink: StubCloudSyncRecordSink(),
            activeCoupleSpaceStore: TestActiveCoupleSpaceStore()
        )

        let status = await service.refresh()

        XCTAssertEqual(status.availability, .available)
        XCTAssertEqual(status.state, .idle)
        XCTAssertTrue(status.diagnostics.isEmpty)
        XCTAssertEqual(status.summary.privateChangeCount, 1)
        XCTAssertEqual(status.summary.sharedChangeCount, 0)
        let snapshots = await client.snapshots()
        XCTAssertEqual(snapshots.tasks.map(\.scope), [.private])
        XCTAssertTrue(snapshots.records.isEmpty)
    }

    func testRefreshPushesPrivateCanonicalAndSharedProjectionRecords() async {
        let task = TaskItem(
            title: "产检预约",
            detail: "协和医院",
            dueAt: Date(timeIntervalSince1970: 2_000),
            status: .todo,
            planLevel: .day,
            ownerUserId: "local",
            coupleSpaceId: "SPACE-1",
            visibility: .coupleShared,
            updatedAt: Date(timeIntervalSince1970: 200),
            version: 2
        )
        let record = Record(
            type: .sleep,
            note: "醒了三次",
            tagsRaw: "poor",
            startAt: Date(timeIntervalSince1970: 1_000),
            endAt: Date(timeIntervalSince1970: 2_000),
            valueText: "5h",
            ownerUserId: "local",
            coupleSpaceId: "SPACE-1",
            visibility: .summaryShared,
            updatedAt: Date(timeIntervalSince1970: 300),
            version: 4
        )
        let client = TestCloudSyncClient(accountAvailability: .available)
        let store = TestActiveCoupleSpaceStore()
        store.activeCoupleSpaceId = "SPACE-1"
        let service = DefaultCloudSyncService(
            client: client,
            taskSource: StubCloudSyncTaskSource(tasks: [task]),
            recordSource: StubCloudSyncRecordSource(records: [record]),
            taskSink: StubCloudSyncTaskSink(),
            recordSink: StubCloudSyncRecordSink(),
            activeCoupleSpaceStore: store
        )

        let status = await service.refresh()

        XCTAssertEqual(status.availability, .available)
        XCTAssertEqual(status.summary.privateChangeCount, 2)
        XCTAssertEqual(status.summary.sharedChangeCount, 2)
        XCTAssertEqual(status.summary.lastPushCount, 4)
        let snapshots = await client.snapshots()
        XCTAssertEqual(snapshots.tasks.map(\.scope), [.private, .shared])
        XCTAssertEqual(snapshots.records.map(\.scope), [.private, .shared])
        XCTAssertEqual(snapshots.records.last?.payload.note, nil)
        XCTAssertEqual(snapshots.records.last?.payload.summaryText, "已记录睡眠状态")
    }

    func testRefreshPullsRemoteChangesAndSendsCanonicalScopesToSinks() async {
        let client = TestCloudSyncClient(
            accountAvailability: .available,
            fetchedTaskRecords: [
                ScopedCloudSyncRecord(
                    scope: .private,
                    payload: CloudSyncTaskPayload(
                        id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
                        title: "来自 iCloud 的任务",
                        detail: "detail",
                        startAt: nil,
                        dueAt: nil,
                        isAllDay: false,
                        priority: 1,
                        status: .todo,
                        planLevel: .day,
                        ownerUserId: "local",
                        coupleSpaceId: nil,
                        visibility: .private,
                        source: .manual,
                        createdAt: Date(timeIntervalSince1970: 100),
                        updatedAt: Date(timeIntervalSince1970: 200),
                        version: 1
                    )
                )
            ],
            fetchedRecordRecords: [
                ScopedCloudSyncRecord(
                    scope: .private,
                    payload: CloudSyncRecordPayload(
                        id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
                        type: .water,
                        summaryText: nil,
                        note: "喝水",
                        tags: [],
                        valueText: "250ml",
                        startAt: Date(timeIntervalSince1970: 100),
                        endAt: nil,
                        ownerUserId: "local",
                        coupleSpaceId: nil,
                        visibility: .private,
                        source: .manual,
                        createdAt: Date(timeIntervalSince1970: 100),
                        updatedAt: Date(timeIntervalSince1970: 200),
                        version: 1
                    )
                )
            ]
        )
        let store = TestActiveCoupleSpaceStore()
        store.activeCoupleSpaceId = "SPACE-1"
        let taskSink = StubCloudSyncTaskSink()
        let recordSink = StubCloudSyncRecordSink()
        let service = DefaultCloudSyncService(
            client: client,
            taskSource: StubCloudSyncTaskSource(tasks: []),
            recordSource: StubCloudSyncRecordSource(records: []),
            taskSink: taskSink,
            recordSink: recordSink,
            activeCoupleSpaceStore: store
        )

        let status = await service.refresh()

        XCTAssertEqual(status.summary.lastPullCount, 2)
        XCTAssertEqual(taskSink.appliedRecords.map(\.scope), [.private])
        XCTAssertEqual(recordSink.appliedRecords.map(\.scope), [.private])
    }
}

private final class StubCloudSyncTaskSource: CloudSyncTaskSource {
    let tasks: [TaskItem]

    init(tasks: [TaskItem]) {
        self.tasks = tasks
    }

    func tasksForCloudSync() async throws -> [TaskItem] {
        tasks
    }
}

private final class StubCloudSyncRecordSource: CloudSyncRecordSource {
    let records: [Record]

    init(records: [Record]) {
        self.records = records
    }

    func recordsForCloudSync() async throws -> [Record] {
        records
    }
}

private final class StubCloudSyncTaskSink: CloudSyncTaskSink {
    private(set) var appliedRecords: [ScopedCloudSyncRecord<CloudSyncTaskPayload>] = []

    func apply(_ records: [ScopedCloudSyncRecord<CloudSyncTaskPayload>]) async throws {
        appliedRecords.append(contentsOf: records)
    }
}

private final class StubCloudSyncRecordSink: CloudSyncRecordSink {
    private(set) var appliedRecords: [ScopedCloudSyncRecord<CloudSyncRecordPayload>] = []

    func apply(_ records: [ScopedCloudSyncRecord<CloudSyncRecordPayload>]) async throws {
        appliedRecords.append(contentsOf: records)
    }
}

private actor TestCloudSyncClient: CloudSyncClient {
    let accountAvailability: ServiceAvailability
    let fetchedTaskRecords: [ScopedCloudSyncRecord<CloudSyncTaskPayload>]
    let fetchedRecordRecords: [ScopedCloudSyncRecord<CloudSyncRecordPayload>]

    private(set) var savedTaskRecords: [ScopedCloudSyncRecord<CloudSyncTaskPayload>] = []
    private(set) var savedRecordRecords: [ScopedCloudSyncRecord<CloudSyncRecordPayload>] = []

    init(
        accountAvailability: ServiceAvailability,
        fetchedTaskRecords: [ScopedCloudSyncRecord<CloudSyncTaskPayload>] = [],
        fetchedRecordRecords: [ScopedCloudSyncRecord<CloudSyncRecordPayload>] = []
    ) {
        self.accountAvailability = accountAvailability
        self.fetchedTaskRecords = fetchedTaskRecords
        self.fetchedRecordRecords = fetchedRecordRecords
    }

    func availability() async -> ServiceAvailability {
        accountAvailability
    }

    func fetchTasks() async throws -> [ScopedCloudSyncRecord<CloudSyncTaskPayload>] {
        fetchedTaskRecords
    }

    func fetchRecords() async throws -> [ScopedCloudSyncRecord<CloudSyncRecordPayload>] {
        fetchedRecordRecords
    }

    func saveTasks(_ records: [ScopedCloudSyncRecord<CloudSyncTaskPayload>]) async throws {
        savedTaskRecords.append(contentsOf: records)
    }

    func saveRecords(_ records: [ScopedCloudSyncRecord<CloudSyncRecordPayload>]) async throws {
        savedRecordRecords.append(contentsOf: records)
    }

    func snapshots() -> (
        tasks: [ScopedCloudSyncRecord<CloudSyncTaskPayload>],
        records: [ScopedCloudSyncRecord<CloudSyncRecordPayload>]
    ) {
        (savedTaskRecords, savedRecordRecords)
    }
}

private final class TestActiveCoupleSpaceStore: ActiveCoupleSpaceStore {
    var activeCoupleSpaceId: String?
}
