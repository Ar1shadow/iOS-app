import Foundation

enum CloudSyncState: Equatable {
    case idle
    case syncing
    case needsAttention
}

enum CloudSyncDiagnosticKind: Equatable {
    case notAuthorized
    case notSupported
    case noActiveSpace
    case networkFailure
    case serviceFailure
}

struct CloudSyncDiagnostic: Equatable {
    let kind: CloudSyncDiagnosticKind
    let message: String
    let recoverySuggestion: String
}

struct CloudSyncStatus: Equatable {
    struct Summary: Equatable {
        let privateChangeCount: Int
        let sharedChangeCount: Int
        let lastPushCount: Int
        let lastPullCount: Int

        static let empty = Summary(
            privateChangeCount: 0,
            sharedChangeCount: 0,
            lastPushCount: 0,
            lastPullCount: 0
        )
    }

    let availability: ServiceAvailability
    let state: CloudSyncState
    let lastSyncAt: Date?
    let summary: Summary
    let diagnostics: [CloudSyncDiagnostic]

    static let unsupported = CloudSyncStatus(
        availability: .notSupported,
        state: .needsAttention,
        lastSyncAt: nil,
        summary: .empty,
        diagnostics: [
            CloudSyncDiagnostic(
                kind: .notSupported,
                message: "当前环境不支持 CloudKit 同步。",
                recoverySuggestion: "请使用已登录 iCloud 的真机，或稍后在支持的环境中重试。"
            )
        ]
    )
}

enum CloudSyncScope: Equatable {
    case `private`
    case shared
}

struct ScopedCloudSyncRecord<Payload: Equatable>: Equatable {
    let scope: CloudSyncScope
    let payload: Payload
}

struct CloudSyncTaskPayload: Codable, Equatable {
    let id: UUID
    let title: String
    let detail: String?
    let startAt: Date?
    let dueAt: Date?
    let isAllDay: Bool
    let priority: Int
    let status: TaskStatus
    let planLevel: PlanLevel
    let ownerUserId: String
    let coupleSpaceId: String?
    let visibility: Visibility
    let source: DataSource
    let createdAt: Date
    let updatedAt: Date
    let version: Int
}

struct CloudSyncRecordPayload: Codable, Equatable {
    let id: UUID
    let type: RecordType
    let summaryText: String?
    let note: String?
    let tags: [String]
    let valueText: String?
    let startAt: Date
    let endAt: Date?
    let ownerUserId: String
    let coupleSpaceId: String?
    let visibility: Visibility
    let source: DataSource
    let createdAt: Date
    let updatedAt: Date
    let version: Int
}

struct CloudSyncTaskRoutePlan: Equatable {
    let privateRecord: ScopedCloudSyncRecord<CloudSyncTaskPayload>
    let sharedRecord: ScopedCloudSyncRecord<CloudSyncTaskPayload>?
}

struct CloudSyncRecordRoutePlan: Equatable {
    let privateRecord: ScopedCloudSyncRecord<CloudSyncRecordPayload>
    let sharedRecord: ScopedCloudSyncRecord<CloudSyncRecordPayload>?
}

enum CloudSyncConflictReason: Equatable {
    case higherVersion
    case newerTimestamp
    case preferredSource
    case preservedCanonicalDetail
    case unchanged
}

struct CloudSyncResolution<Payload: Equatable>: Equatable {
    let winner: Payload
    let reason: CloudSyncConflictReason
}

protocol CloudSyncTaskSource {
    func tasksForCloudSync() async throws -> [TaskItem]
}

protocol CloudSyncRecordSource {
    func recordsForCloudSync() async throws -> [Record]
}

protocol CloudSyncTaskSink {
    func apply(_ records: [ScopedCloudSyncRecord<CloudSyncTaskPayload>]) async throws
}

protocol CloudSyncRecordSink {
    func apply(_ records: [ScopedCloudSyncRecord<CloudSyncRecordPayload>]) async throws
}

protocol CloudSyncClient {
    func availability() async -> ServiceAvailability
    func fetchTasks() async throws -> [ScopedCloudSyncRecord<CloudSyncTaskPayload>]
    func fetchRecords() async throws -> [ScopedCloudSyncRecord<CloudSyncRecordPayload>]
    func saveTasks(_ records: [ScopedCloudSyncRecord<CloudSyncTaskPayload>]) async throws
    func saveRecords(_ records: [ScopedCloudSyncRecord<CloudSyncRecordPayload>]) async throws
}
