import Foundation

#if canImport(CloudKit)
import CloudKit
#endif

final class CloudKitShareInvitationClientLive: CloudKitShareInvitationClient {
    static let zoneName = "CoupleLifeSharedZone"
    static let rootRecordType = "CoupleSpaceRoot"
    static let rootRecordName = "couple-space-root"

    #if canImport(CloudKit)
    private let container: CKContainer
    private var database: CKDatabase { container.privateCloudDatabase }
    private let zoneID: CKRecordZone.ID
    private let rootRecordID: CKRecord.ID

    init(container: CKContainer = .default()) {
        self.container = container
        self.zoneID = CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName)
        self.rootRecordID = CKRecord.ID(recordName: Self.rootRecordName, zoneID: zoneID)
    }
    #else
    init() {}
    #endif

    func availability() async -> ServiceAvailability {
        #if canImport(CloudKit)
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                return .available
            case .noAccount, .restricted:
                return .notAuthorized
            case .couldNotDetermine:
                return .failed("CloudKit account status could not be determined. Try again later.")
            case .temporarilyUnavailable:
                return .failed("CloudKit account status is temporarily unavailable. Try again later.")
            @unknown default:
                return .failed("CloudKit account status is unknown.")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
        #else
        return .notSupported
        #endif
    }

    func ensureShareRootAndCreate() async throws -> CloudShareInvitationCreateResult {
        #if canImport(CloudKit)
        do {
            let root = try await ensureShareRoot()
            return try await createShare(rootRecord: root)
        } catch let error as CloudShareInvitationError {
            throw error
        } catch {
            throw mapError(error)
        }
        #else
        throw CloudShareInvitationError(code: "not_supported")
        #endif
    }

    func fetchExistingShare() async throws -> CloudShareInvitationCreateResult? {
        #if canImport(CloudKit)
        do {
            try await ensureZone()
            let root = try await database.record(for: rootRecordID)
            guard let shareReference = root.share else { return nil }
            let shareRecord = try await database.record(for: shareReference.recordID)
            guard let share = shareRecord as? CKShare, let url = share.url else { return nil }
            return CloudShareInvitationCreateResult(
                shareURL: url,
                participantCount: max(0, share.participants.count - 1)
            )
        } catch let ckError as CKError where ckError.code == .unknownItem || ckError.code == .zoneNotFound {
            return nil
        } catch {
            throw mapError(error)
        }
        #else
        return nil
        #endif
    }

    func revokeShare() async throws {
        #if canImport(CloudKit)
        do {
            try await ensureZone()
            let root = try await database.record(for: rootRecordID)
            guard let shareReference = root.share else {
                throw CloudShareInvitationError(code: "share_not_found")
            }
            try await deleteRecord(withID: shareReference.recordID)
        } catch let ckError as CKError where ckError.code == .unknownItem || ckError.code == .zoneNotFound {
            throw CloudShareInvitationError(code: "share_not_found")
        } catch let error as CloudShareInvitationError {
            throw error
        } catch {
            throw mapError(error)
        }
        #else
        throw CloudShareInvitationError(code: "not_supported")
        #endif
    }
}

#if canImport(CloudKit)
private extension CloudKitShareInvitationClientLive {
    func ensureShareRoot() async throws -> CKRecord {
        try await ensureZone()
        do {
            return try await database.record(for: rootRecordID)
        } catch let ckError as CKError where ckError.code == .unknownItem {
            let record = CKRecord(recordType: Self.rootRecordType, recordID: rootRecordID)
            record["createdAt"] = Date() as CKRecordValue
            return try await saveRecord(record)
        }
    }

    func createShare(rootRecord: CKRecord) async throws -> CloudShareInvitationCreateResult {
        let share = CKShare(rootRecord: rootRecord)
        share.publicPermission = .none
        share[CKShare.SystemFieldKey.title] = "CoupleLife 共享" as CKRecordValue

        let savedRecords = try await modifyRecords([share, rootRecord])
        guard let savedShare = savedRecords.compactMap({ $0 as? CKShare }).first else {
            throw CloudShareInvitationError(code: "missing_share_record")
        }
        guard let url = savedShare.url else {
            throw CloudShareInvitationError(code: "missing_share_url")
        }
        return CloudShareInvitationCreateResult(
            shareURL: url,
            participantCount: max(0, savedShare.participants.count - 1)
        )
    }

    func ensureZone() async throws {
        let zone = CKRecordZone(zoneID: zoneID)
        do {
            _ = try await database.recordZone(for: zoneID)
        } catch let ckError as CKError where ckError.code == .zoneNotFound || ckError.code == .unknownItem {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let op = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
                op.modifyRecordZonesResultBlock = { result in
                    switch result {
                    case .success: continuation.resume()
                    case .failure(let error): continuation.resume(throwing: error)
                    }
                }
                database.add(op)
            }
        }
    }

    func saveRecord(_ record: CKRecord) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            database.save(record) { saved, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let saved {
                    continuation.resume(returning: saved)
                } else {
                    continuation.resume(throwing: CloudShareInvitationError(code: "missing_saved_record"))
                }
            }
        }
    }

    func modifyRecords(_ records: [CKRecord]) async throws -> [CKRecord] {
        try await withCheckedThrowingContinuation { continuation in
            let op = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
            op.savePolicy = .ifServerRecordUnchanged
            var saved: [CKRecord] = []
            var firstError: Error?

            op.perRecordSaveBlock = { _, result in
                switch result {
                case .success(let record): saved.append(record)
                case .failure(let error):
                    if firstError == nil { firstError = error }
                }
            }
            op.modifyRecordsResultBlock = { result in
                if let firstError {
                    continuation.resume(throwing: firstError)
                    return
                }
                switch result {
                case .success: continuation.resume(returning: saved)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
            database.add(op)
        }
    }

    func deleteRecord(withID id: CKRecord.ID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let op = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [id])
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
            database.add(op)
        }
    }

    func mapError(_ error: Error) -> CloudShareInvitationError {
        if let invitationError = error as? CloudShareInvitationError {
            return invitationError
        }
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated: return CloudShareInvitationError(code: "not_authorized")
            case .networkUnavailable, .networkFailure: return CloudShareInvitationError(code: "network_unavailable")
            case .badContainer, .missingEntitlement: return CloudShareInvitationError(code: "container_not_available")
            case .unknownItem: return CloudShareInvitationError(code: "share_not_found")
            default: return CloudShareInvitationError(code: "ck_\(String(describing: ckError.code))")
            }
        }
        let nsError = error as NSError
        if nsError.domain == CKErrorDomain, let code = CKError.Code(rawValue: nsError.code) {
            return CloudShareInvitationError(code: "ck_\(String(describing: code))")
        }
        if !nsError.domain.isEmpty {
            return CloudShareInvitationError(code: "\(nsError.domain)#\(nsError.code)")
        }
        return CloudShareInvitationError(code: "unknown_error")
    }
}
#endif
