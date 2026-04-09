import Foundation

struct CloudSyncRoutePlanner {
    func plan(task: TaskItem, activeCoupleSpaceId: String? = nil) -> CloudSyncTaskRoutePlan {
        let payload = CloudSyncTaskPayload(
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

        let privateRecord = ScopedCloudSyncRecord(scope: .private, payload: payload)
        let activeSpaceId = activeCoupleSpaceId ?? task.coupleSpaceId
        let shouldShare = task.visibility != .private &&
            task.coupleSpaceId != nil &&
            task.coupleSpaceId == activeSpaceId
        let sharedRecord = shouldShare ? ScopedCloudSyncRecord(scope: .shared, payload: payload) : nil

        return CloudSyncTaskRoutePlan(
            privateRecord: privateRecord,
            sharedRecord: sharedRecord
        )
    }

    func plan(record: Record, activeCoupleSpaceId: String? = nil) -> CloudSyncRecordRoutePlan {
        let privatePayload = CloudSyncRecordPayload(
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
        let privateRecord = ScopedCloudSyncRecord(scope: .private, payload: privatePayload)

        let activeSpaceId = activeCoupleSpaceId ?? record.coupleSpaceId
        guard
            record.visibility != .private,
            record.coupleSpaceId != nil,
            record.coupleSpaceId == activeSpaceId
        else {
            return CloudSyncRecordRoutePlan(privateRecord: privateRecord, sharedRecord: nil)
        }

        let content = VisibilityPolicy.record(type: record.type).sharedRecordContent(
            visibility: record.visibility,
            note: record.note,
            tagsRaw: record.tagsRaw,
            valueText: record.valueText
        )
        let sharedPayload = CloudSyncRecordPayload(
            id: record.id,
            type: record.type,
            summaryText: content.summaryText,
            note: content.note,
            tags: content.tags,
            valueText: content.valueText,
            startAt: record.startAt,
            endAt: record.endAt,
            ownerUserId: record.ownerUserId,
            coupleSpaceId: record.coupleSpaceId,
            visibility: content.visibility,
            source: record.source,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            version: record.version
        )

        return CloudSyncRecordRoutePlan(
            privateRecord: privateRecord,
            sharedRecord: ScopedCloudSyncRecord(scope: .shared, payload: sharedPayload)
        )
    }
}
