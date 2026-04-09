import Foundation
import SwiftData

final class SwiftDataCloudSyncTaskStore: CloudSyncTaskSource, CloudSyncTaskSink {
    private let context: ModelContext
    private let resolver: CloudSyncConflictResolver
    private let currentUserId: String

    init(
        context: ModelContext,
        currentUserId: String = CurrentUser.id,
        resolver: CloudSyncConflictResolver = CloudSyncConflictResolver()
    ) {
        self.context = context
        self.currentUserId = currentUserId
        self.resolver = resolver
    }

    func tasksForCloudSync() async throws -> [TaskItem] {
        let currentUserId = self.currentUserId
        let predicate = #Predicate<TaskItem> { $0.ownerUserId == currentUserId }
        return try context.fetch(FetchDescriptor<TaskItem>(predicate: predicate))
    }

    func apply(_ records: [ScopedCloudSyncRecord<CloudSyncTaskPayload>]) async throws {
        for record in records where shouldApply(record) {
            if let existing = try fetchTask(id: record.payload.id) {
                let resolved = resolver.resolveCanonicalTask(local: payload(from: existing), remote: record.payload)
                apply(resolved.winner, to: existing)
            } else {
                context.insert(task(from: record.payload))
            }
        }
        try context.save()
    }

    private func shouldApply(_ record: ScopedCloudSyncRecord<CloudSyncTaskPayload>) -> Bool {
        switch record.scope {
        case .private:
            return true
        case .shared:
            return record.payload.ownerUserId != currentUserId
        }
    }

    private func fetchTask(id: UUID) throws -> TaskItem? {
        let predicate = #Predicate<TaskItem> { $0.id == id }
        return try context.fetch(FetchDescriptor<TaskItem>(predicate: predicate)).first
    }

    private func payload(from task: TaskItem) -> CloudSyncTaskPayload {
        CloudSyncTaskPayload(
            id: task.id,
            title: task.title,
            detail: task.detail,
            startAt: task.startAt,
            dueAt: task.dueAt,
            isAllDay: task.isAllDay,
            priority: task.priority,
            status: task.status,
            planLevel: task.planLevel,
            ownerUserId: task.ownerUserId,
            coupleSpaceId: task.coupleSpaceId,
            visibility: task.visibility,
            source: task.source,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
            version: task.version
        )
    }

    private func task(from payload: CloudSyncTaskPayload) -> TaskItem {
        TaskItem(
            id: payload.id,
            title: payload.title,
            detail: payload.detail,
            startAt: payload.startAt,
            dueAt: payload.dueAt,
            isAllDay: payload.isAllDay,
            priority: payload.priority,
            status: payload.status,
            planLevel: payload.planLevel,
            ownerUserId: payload.ownerUserId,
            coupleSpaceId: payload.coupleSpaceId,
            visibility: payload.visibility,
            source: payload.source,
            createdAt: payload.createdAt,
            updatedAt: payload.updatedAt,
            version: payload.version
        )
    }

    private func apply(_ payload: CloudSyncTaskPayload, to task: TaskItem) {
        task.title = payload.title
        task.detail = payload.detail
        task.startAt = payload.startAt
        task.dueAt = payload.dueAt
        task.isAllDay = payload.isAllDay
        task.priority = payload.priority
        task.status = payload.status
        task.planLevel = payload.planLevel
        task.ownerUserId = payload.ownerUserId
        task.coupleSpaceId = payload.coupleSpaceId
        task.visibility = payload.visibility
        task.source = payload.source
        task.createdAt = payload.createdAt
        task.updatedAt = payload.updatedAt
        task.version = payload.version
    }
}

final class SwiftDataCloudSyncRecordStore: CloudSyncRecordSource, CloudSyncRecordSink {
    private let context: ModelContext
    private let resolver: CloudSyncConflictResolver
    private let currentUserId: String

    init(
        context: ModelContext,
        currentUserId: String = CurrentUser.id,
        resolver: CloudSyncConflictResolver = CloudSyncConflictResolver()
    ) {
        self.context = context
        self.currentUserId = currentUserId
        self.resolver = resolver
    }

    func recordsForCloudSync() async throws -> [Record] {
        let currentUserId = self.currentUserId
        let predicate = #Predicate<Record> { $0.ownerUserId == currentUserId }
        return try context.fetch(FetchDescriptor<Record>(predicate: predicate))
    }

    func apply(_ records: [ScopedCloudSyncRecord<CloudSyncRecordPayload>]) async throws {
        for record in records where shouldApply(record) {
            if let existing = try fetchRecord(id: record.payload.id) {
                let resolved = resolver.resolveCanonicalRecord(
                    local: payload(from: existing),
                    remote: record.payload,
                    remoteScope: record.scope
                )
                apply(resolved.winner, to: existing)
            } else {
                context.insert(model(from: record.payload))
            }
        }
        try context.save()
    }

    private func shouldApply(_ record: ScopedCloudSyncRecord<CloudSyncRecordPayload>) -> Bool {
        switch record.scope {
        case .private:
            return true
        case .shared:
            return record.payload.ownerUserId != currentUserId
        }
    }

    private func fetchRecord(id: UUID) throws -> Record? {
        let predicate = #Predicate<Record> { $0.id == id }
        return try context.fetch(FetchDescriptor<Record>(predicate: predicate)).first
    }

    private func payload(from record: Record) -> CloudSyncRecordPayload {
        CloudSyncRecordPayload(
            id: record.id,
            type: record.type,
            summaryText: nil,
            note: record.note,
            tags: record.tags,
            valueText: record.valueText,
            startAt: record.startAt,
            endAt: record.endAt,
            ownerUserId: record.ownerUserId,
            coupleSpaceId: record.coupleSpaceId,
            visibility: record.visibility,
            source: record.source,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            version: record.version
        )
    }

    private func model(from payload: CloudSyncRecordPayload) -> Record {
        let note: String?
        if payload.visibility == .summaryShared, payload.note == nil {
            note = payload.summaryText
        } else {
            note = payload.note
        }

        return Record(
            id: payload.id,
            type: payload.type,
            note: note,
            tagsRaw: payload.tags.joined(separator: ","),
            startAt: payload.startAt,
            endAt: payload.endAt,
            valueText: payload.valueText,
            ownerUserId: payload.ownerUserId,
            coupleSpaceId: payload.coupleSpaceId,
            visibility: payload.visibility,
            source: payload.source,
            createdAt: payload.createdAt,
            updatedAt: payload.updatedAt,
            version: payload.version
        )
    }

    private func apply(_ payload: CloudSyncRecordPayload, to record: Record) {
        record.type = payload.type
        if payload.visibility == .summaryShared, payload.note == nil {
            record.note = payload.summaryText
        } else {
            record.note = payload.note
        }
        record.tags = payload.tags
        record.valueText = payload.valueText
        record.startAt = payload.startAt
        record.endAt = payload.endAt
        record.ownerUserId = payload.ownerUserId
        record.coupleSpaceId = payload.coupleSpaceId
        record.visibility = payload.visibility
        record.source = payload.source
        record.createdAt = payload.createdAt
        record.updatedAt = payload.updatedAt
        record.version = payload.version
    }
}
