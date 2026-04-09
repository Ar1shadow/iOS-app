import Foundation

final class DefaultCloudSyncService: CloudSyncService {
    private let client: any CloudSyncClient
    private let taskSource: any CloudSyncTaskSource
    private let recordSource: any CloudSyncRecordSource
    private let taskSink: any CloudSyncTaskSink
    private let recordSink: any CloudSyncRecordSink
    private let activeCoupleSpaceStore: any ActiveCoupleSpaceStore
    private let routePlanner: CloudSyncRoutePlanner
    private let nowProvider: () -> Date

    private var cachedStatus: CloudSyncStatus

    init(
        client: any CloudSyncClient,
        taskSource: any CloudSyncTaskSource,
        recordSource: any CloudSyncRecordSource,
        taskSink: any CloudSyncTaskSink,
        recordSink: any CloudSyncRecordSink,
        activeCoupleSpaceStore: any ActiveCoupleSpaceStore,
        routePlanner: CloudSyncRoutePlanner = CloudSyncRoutePlanner(),
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.client = client
        self.taskSource = taskSource
        self.recordSource = recordSource
        self.taskSink = taskSink
        self.recordSink = recordSink
        self.activeCoupleSpaceStore = activeCoupleSpaceStore
        self.routePlanner = routePlanner
        self.nowProvider = nowProvider
        self.cachedStatus = CloudSyncStatus(
            availability: .notSupported,
            state: .needsAttention,
            lastSyncAt: nil,
            summary: .empty,
            diagnostics: []
        )
    }

    func availability() async -> ServiceAvailability {
        await client.availability()
    }

    func currentStatus() async -> CloudSyncStatus {
        let currentAvailability = await client.availability()
        if cachedStatus.availability == currentAvailability {
            return cachedStatus
        }
        let status = statusForAvailability(currentAvailability)
        cachedStatus = status
        return status
    }

    func refresh() async -> CloudSyncStatus {
        let currentAvailability = await client.availability()
        guard currentAvailability == .available else {
            let status = statusForAvailability(currentAvailability)
            cachedStatus = status
            return status
        }

        do {
            let localTasks = try await taskSource.tasksForCloudSync()
            let localRecords = try await recordSource.recordsForCloudSync()
            let activeCoupleSpaceId = activeCoupleSpaceStore.activeCoupleSpaceId

            let plannedTaskRecords = localTasks.flatMap { task -> [ScopedCloudSyncRecord<CloudSyncTaskPayload>] in
                let plan = routePlanner.plan(task: task, activeCoupleSpaceId: activeCoupleSpaceId ?? "")
                return [plan.privateRecord, plan.sharedRecord].compactMap { $0 }
            }
            let plannedRecordRecords = localRecords.flatMap { record -> [ScopedCloudSyncRecord<CloudSyncRecordPayload>] in
                let plan = routePlanner.plan(record: record, activeCoupleSpaceId: activeCoupleSpaceId ?? "")
                return [plan.privateRecord, plan.sharedRecord].compactMap { $0 }
            }

            try await client.saveTasks(plannedTaskRecords)
            try await client.saveRecords(plannedRecordRecords)

            let fetchedTaskRecords = try await client.fetchTasks()
            let fetchedRecordRecords = try await client.fetchRecords()

            try await taskSink.apply(fetchedTaskRecords)
            try await recordSink.apply(fetchedRecordRecords)

            let status = CloudSyncStatus(
                availability: .available,
                state: .idle,
                lastSyncAt: nowProvider(),
                summary: CloudSyncStatus.Summary(
                    privateChangeCount: plannedTaskRecords.filter { $0.scope == .private }.count +
                        plannedRecordRecords.filter { $0.scope == .private }.count,
                    sharedChangeCount: plannedTaskRecords.filter { $0.scope == .shared }.count +
                        plannedRecordRecords.filter { $0.scope == .shared }.count,
                    lastPushCount: plannedTaskRecords.count + plannedRecordRecords.count,
                    lastPullCount: fetchedTaskRecords.count + fetchedRecordRecords.count
                ),
                diagnostics: []
            )
            cachedStatus = status
            return status
        } catch {
            let status = CloudSyncStatus(
                availability: .failed(error.localizedDescription),
                state: .needsAttention,
                lastSyncAt: nil,
                summary: .empty,
                diagnostics: [
                    CloudSyncDiagnostic(
                        kind: .serviceFailure,
                        message: error.localizedDescription,
                        recoverySuggestion: "稍后重试；如果问题持续，请检查 iCloud 与网络状态。"
                    )
                ]
            )
            cachedStatus = status
            return status
        }
    }

    private func statusForAvailability(_ availability: ServiceAvailability) -> CloudSyncStatus {
        switch availability {
        case .available:
            return CloudSyncStatus(
                availability: .available,
                state: .idle,
                lastSyncAt: cachedStatus.lastSyncAt,
                summary: cachedStatus.summary,
                diagnostics: []
            )
        case .notAuthorized:
            return CloudSyncStatus(
                availability: .notAuthorized,
                state: .needsAttention,
                lastSyncAt: nil,
                summary: .empty,
                diagnostics: [
                    CloudSyncDiagnostic(
                        kind: .notAuthorized,
                        message: "当前 iCloud 账号未授权 CloudKit 同步。",
                        recoverySuggestion: "请确认设备已登录 iCloud，并允许 CoupleLife 使用 iCloud。"
                    )
                ]
            )
        case .notSupported:
            return .unsupported
        case .failed(let message):
            return CloudSyncStatus(
                availability: .failed(message),
                state: .needsAttention,
                lastSyncAt: nil,
                summary: .empty,
                diagnostics: [
                    CloudSyncDiagnostic(
                        kind: .serviceFailure,
                        message: message,
                        recoverySuggestion: "检查网络、iCloud 登录状态，或稍后重新尝试。"
                    )
                ]
            )
        }
    }
}
