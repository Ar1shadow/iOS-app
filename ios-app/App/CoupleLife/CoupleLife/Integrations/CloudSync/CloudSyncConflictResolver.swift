import Foundation

struct CloudSyncConflictResolver {
    func resolveCanonicalTask(
        local: CloudSyncTaskPayload,
        remote: CloudSyncTaskPayload
    ) -> CloudSyncResolution<CloudSyncTaskPayload> {
        if remote.version != local.version {
            return CloudSyncResolution(
                winner: remote.version > local.version ? remote : local,
                reason: .higherVersion
            )
        }
        if remote.updatedAt != local.updatedAt {
            return CloudSyncResolution(
                winner: remote.updatedAt > local.updatedAt ? remote : local,
                reason: .newerTimestamp
            )
        }
        if remote.source != local.source {
            return CloudSyncResolution(
                winner: preferredTaskPayload(local: local, remote: remote),
                reason: .preferredSource
            )
        }
        return CloudSyncResolution(winner: local, reason: .unchanged)
    }

    func resolveCanonicalRecord(
        local: CloudSyncRecordPayload,
        remote: CloudSyncRecordPayload,
        remoteScope: CloudSyncScope = .private
    ) -> CloudSyncResolution<CloudSyncRecordPayload> {
        if remoteScope == .shared, localHasMoreDetailThanProjection(local: local, remote: remote) {
            return CloudSyncResolution(winner: local, reason: .preservedCanonicalDetail)
        }
        if remote.version != local.version {
            return CloudSyncResolution(
                winner: remote.version > local.version ? remote : local,
                reason: .higherVersion
            )
        }
        if remote.updatedAt != local.updatedAt {
            return CloudSyncResolution(
                winner: remote.updatedAt > local.updatedAt ? remote : local,
                reason: .newerTimestamp
            )
        }
        if remote.source != local.source {
            return CloudSyncResolution(
                winner: preferredRecordPayload(local: local, remote: remote),
                reason: .preferredSource
            )
        }
        return CloudSyncResolution(winner: local, reason: .unchanged)
    }

    private func preferredTaskPayload(
        local: CloudSyncTaskPayload,
        remote: CloudSyncTaskPayload
    ) -> CloudSyncTaskPayload {
        remote.source == .manual ? remote : local
    }

    private func preferredRecordPayload(
        local: CloudSyncRecordPayload,
        remote: CloudSyncRecordPayload
    ) -> CloudSyncRecordPayload {
        remote.source == .manual ? remote : local
    }

    private func localHasMoreDetailThanProjection(
        local: CloudSyncRecordPayload,
        remote: CloudSyncRecordPayload
    ) -> Bool {
        (local.note != nil && remote.note == nil) ||
        (!local.tags.isEmpty && remote.tags.isEmpty) ||
        (local.valueText != nil && remote.valueText == nil)
    }
}
