import Foundation
#if canImport(CloudKit)
import CloudKit
#endif

final class CloudKitCloudSyncClient: CloudSyncClient {
    #if canImport(CloudKit)
    private let container: CKContainer

    init(container: CKContainer = .default()) {
        self.container = container
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
            case .noAccount, .couldNotDetermine, .temporarilyUnavailable, .restricted:
                return .notAuthorized
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

    func fetchTasks() async throws -> [ScopedCloudSyncRecord<CloudSyncTaskPayload>] {
        #if canImport(CloudKit)
        let privateRecords = try await fetchTaskRecords(from: container.privateCloudDatabase)
        let sharedRecords = try await fetchTaskRecords(from: container.sharedCloudDatabase)
        return deduplicatedTasks(privateRecords + sharedRecords)
        #else
        return []
        #endif
    }

    func fetchRecords() async throws -> [ScopedCloudSyncRecord<CloudSyncRecordPayload>] {
        #if canImport(CloudKit)
        let privateRecords = try await fetchRecordRecords(from: container.privateCloudDatabase)
        let sharedRecords = try await fetchRecordRecords(from: container.sharedCloudDatabase)
        return deduplicatedRecords(privateRecords + sharedRecords)
        #else
        return []
        #endif
    }

    func saveTasks(_ records: [ScopedCloudSyncRecord<CloudSyncTaskPayload>]) async throws {
        #if canImport(CloudKit)
        let privateRecords = records
            .filter { $0.scope == .private }
            .map { makeTaskRecord(from: $0) }
        let sharedRecords = records
            .filter { $0.scope == .shared }
            .map { makeTaskRecord(from: $0) }

        try await save(privateRecords, to: container.privateCloudDatabase)
        try await save(sharedRecords, to: container.sharedCloudDatabase)
        #endif
    }

    func saveRecords(_ records: [ScopedCloudSyncRecord<CloudSyncRecordPayload>]) async throws {
        #if canImport(CloudKit)
        let privateRecords = records
            .filter { $0.scope == .private }
            .map { makeRecordRecord(from: $0) }
        let sharedRecords = records
            .filter { $0.scope == .shared }
            .map { makeRecordRecord(from: $0) }

        try await save(privateRecords, to: container.privateCloudDatabase)
        try await save(sharedRecords, to: container.sharedCloudDatabase)
        #endif
    }
}

#if canImport(CloudKit)
extension CloudKitCloudSyncClient {
    enum RecordKind {
        static let task = "CloudSyncTask"
        static let record = "CloudSyncRecord"
    }

    enum Field {
        static let logicalScope = "logicalScope"
        static let uuid = "uuid"
        static let title = "title"
        static let detail = "detail"
        static let startAt = "startAt"
        static let dueAt = "dueAt"
        static let isAllDay = "isAllDay"
        static let priority = "priority"
        static let status = "status"
        static let planLevel = "planLevel"
        static let type = "type"
        static let summaryText = "summaryText"
        static let note = "note"
        static let tags = "tags"
        static let valueText = "valueText"
        static let endAt = "endAt"
        static let ownerUserId = "ownerUserId"
        static let coupleSpaceId = "coupleSpaceId"
        static let visibility = "visibility"
        static let source = "source"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
        static let version = "version"
    }

    func fetchTaskRecords(from database: CKDatabase) async throws -> [ScopedCloudSyncRecord<CloudSyncTaskPayload>] {
        let records = try await fetch(recordType: RecordKind.task, from: database)
        return try records.map(taskRecord(from:))
    }

    func fetchRecordRecords(from database: CKDatabase) async throws -> [ScopedCloudSyncRecord<CloudSyncRecordPayload>] {
        let records = try await fetch(recordType: RecordKind.record, from: database)
        return try records.map(recordRecord(from:))
    }

    func fetch(recordType: String, from database: CKDatabase) async throws -> [CKRecord] {
        var cursor: CKQueryOperation.Cursor?
        var records: [CKRecord] = []

        repeat {
            let page = try await fetchPage(recordType: recordType, cursor: cursor, from: database)
            records.append(contentsOf: page.records)
            cursor = page.cursor
        } while cursor != nil

        return records
    }

    func fetchPage(
        recordType: String,
        cursor: CKQueryOperation.Cursor?,
        from database: CKDatabase
    ) async throws -> (records: [CKRecord], cursor: CKQueryOperation.Cursor?) {
        try await withCheckedThrowingContinuation { continuation in
            let operation: CKQueryOperation
            if let cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
                operation = CKQueryOperation(query: query)
            }

            operation.resultsLimit = CKQueryOperation.maximumResults
            var records: [CKRecord] = []
            var recordError: Error?

            operation.recordMatchedBlock = { _, result in
                switch result {
                case .success(let record):
                    records.append(record)
                case .failure(let error):
                    recordError = error
                }
            }

            operation.queryResultBlock = { result in
                if let recordError {
                    continuation.resume(throwing: recordError)
                    return
                }

                switch result {
                case .success(let cursor):
                    continuation.resume(returning: (records: records, cursor: cursor))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
    }

    func save(_ records: [CKRecord], to database: CKDatabase) async throws {
        guard !records.isEmpty else { return }

        try await withCheckedThrowingContinuation { continuation in
            let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
            operation.savePolicy = .changedKeys
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(operation)
        }
    }

    func makeTaskRecord(from scopedRecord: ScopedCloudSyncRecord<CloudSyncTaskPayload>) -> CKRecord {
        let payload = scopedRecord.payload
        let record = CKRecord(
            recordType: RecordKind.task,
            recordID: CKRecord.ID(recordName: recordName(kind: RecordKind.task, id: payload.id, scope: scopedRecord.scope))
        )
        record[Field.logicalScope] = scopedRecord.scope.rawCloudValue
        record[Field.uuid] = payload.id.uuidString
        record[Field.title] = payload.title
        record[Field.detail] = payload.detail
        record[Field.startAt] = payload.startAt
        record[Field.dueAt] = payload.dueAt
        record[Field.isAllDay] = payload.isAllDay
        record[Field.priority] = payload.priority
        record[Field.status] = payload.status.rawValue
        record[Field.planLevel] = payload.planLevel.rawValue
        record[Field.ownerUserId] = payload.ownerUserId
        record[Field.coupleSpaceId] = payload.coupleSpaceId
        record[Field.visibility] = payload.visibility.rawValue
        record[Field.source] = payload.source.rawValue
        record[Field.createdAt] = payload.createdAt
        record[Field.updatedAt] = payload.updatedAt
        record[Field.version] = payload.version
        return record
    }

    func makeRecordRecord(from scopedRecord: ScopedCloudSyncRecord<CloudSyncRecordPayload>) -> CKRecord {
        let payload = scopedRecord.payload
        let record = CKRecord(
            recordType: RecordKind.record,
            recordID: CKRecord.ID(recordName: recordName(kind: RecordKind.record, id: payload.id, scope: scopedRecord.scope))
        )
        record[Field.logicalScope] = scopedRecord.scope.rawCloudValue
        record[Field.uuid] = payload.id.uuidString
        record[Field.type] = payload.type.rawValue
        record[Field.summaryText] = payload.summaryText
        record[Field.note] = payload.note
        record[Field.tags] = payload.tags
        record[Field.valueText] = payload.valueText
        record[Field.startAt] = payload.startAt
        record[Field.endAt] = payload.endAt
        record[Field.ownerUserId] = payload.ownerUserId
        record[Field.coupleSpaceId] = payload.coupleSpaceId
        record[Field.visibility] = payload.visibility.rawValue
        record[Field.source] = payload.source.rawValue
        record[Field.createdAt] = payload.createdAt
        record[Field.updatedAt] = payload.updatedAt
        record[Field.version] = payload.version
        return record
    }

    func taskRecord(from record: CKRecord) throws -> ScopedCloudSyncRecord<CloudSyncTaskPayload> {
        let scope = try scope(from: record)
        let payload = CloudSyncTaskPayload(
            id: try uuid(from: record),
            title: try requiredString(Field.title, from: record),
            detail: record[Field.detail] as? String,
            startAt: record[Field.startAt] as? Date,
            dueAt: record[Field.dueAt] as? Date,
            isAllDay: (record[Field.isAllDay] as? Bool) ?? false,
            priority: (record[Field.priority] as? Int) ?? 0,
            status: TaskStatus(rawValue: try requiredString(Field.status, from: record)) ?? .todo,
            planLevel: PlanLevel(rawValue: try requiredString(Field.planLevel, from: record)) ?? .day,
            ownerUserId: try requiredString(Field.ownerUserId, from: record),
            coupleSpaceId: record[Field.coupleSpaceId] as? String,
            visibility: Visibility(rawValue: try requiredString(Field.visibility, from: record)) ?? .private,
            source: DataSource(rawValue: try requiredString(Field.source, from: record)) ?? .manual,
            createdAt: try requiredDate(Field.createdAt, from: record),
            updatedAt: try requiredDate(Field.updatedAt, from: record),
            version: (record[Field.version] as? Int) ?? 1
        )
        return ScopedCloudSyncRecord(scope: scope, payload: payload)
    }

    func recordRecord(from record: CKRecord) throws -> ScopedCloudSyncRecord<CloudSyncRecordPayload> {
        let scope = try scope(from: record)
        let payload = CloudSyncRecordPayload(
            id: try uuid(from: record),
            type: RecordType(rawValue: try requiredString(Field.type, from: record)) ?? .custom,
            summaryText: record[Field.summaryText] as? String,
            note: record[Field.note] as? String,
            tags: (record[Field.tags] as? [String]) ?? [],
            valueText: record[Field.valueText] as? String,
            startAt: try requiredDate(Field.startAt, from: record),
            endAt: record[Field.endAt] as? Date,
            ownerUserId: try requiredString(Field.ownerUserId, from: record),
            coupleSpaceId: record[Field.coupleSpaceId] as? String,
            visibility: Visibility(rawValue: try requiredString(Field.visibility, from: record)) ?? .private,
            source: DataSource(rawValue: try requiredString(Field.source, from: record)) ?? .manual,
            createdAt: try requiredDate(Field.createdAt, from: record),
            updatedAt: try requiredDate(Field.updatedAt, from: record),
            version: (record[Field.version] as? Int) ?? 1
        )
        return ScopedCloudSyncRecord(scope: scope, payload: payload)
    }

    func uuid(from record: CKRecord) throws -> UUID {
        guard
            let rawValue = record[Field.uuid] as? String,
            let uuid = UUID(uuidString: rawValue)
        else {
            throw CloudKitCloudSyncClientError.missingField(Field.uuid)
        }
        return uuid
    }

    func scope(from record: CKRecord) throws -> CloudSyncScope {
        guard let rawValue = record[Field.logicalScope] as? String else {
            throw CloudKitCloudSyncClientError.missingField(Field.logicalScope)
        }
        switch rawValue {
        case CloudSyncScope.private.rawCloudValue:
            return .private
        case CloudSyncScope.shared.rawCloudValue:
            return .shared
        default:
            throw CloudKitCloudSyncClientError.invalidField(Field.logicalScope)
        }
    }

    func requiredString(_ field: String, from record: CKRecord) throws -> String {
        guard let value = record[field] as? String else {
            throw CloudKitCloudSyncClientError.missingField(field)
        }
        return value
    }

    func requiredDate(_ field: String, from record: CKRecord) throws -> Date {
        guard let value = record[field] as? Date else {
            throw CloudKitCloudSyncClientError.missingField(field)
        }
        return value
    }

    func recordName(kind: String, id: UUID, scope: CloudSyncScope) -> String {
        "\(kind).\(id.uuidString).\(scope.rawCloudValue)"
    }

    func deduplicatedTasks(
        _ records: [ScopedCloudSyncRecord<CloudSyncTaskPayload>]
    ) -> [ScopedCloudSyncRecord<CloudSyncTaskPayload>] {
        var indexed: [String: ScopedCloudSyncRecord<CloudSyncTaskPayload>] = [:]
        for record in records {
            let key = dedupeKey(id: record.payload.id, ownerUserId: record.payload.ownerUserId, scope: record.scope)
            if let existing = indexed[key], existing.payload.updatedAt >= record.payload.updatedAt {
                continue
            }
            indexed[key] = record
        }
        return Array(indexed.values)
    }

    func deduplicatedRecords(
        _ records: [ScopedCloudSyncRecord<CloudSyncRecordPayload>]
    ) -> [ScopedCloudSyncRecord<CloudSyncRecordPayload>] {
        var indexed: [String: ScopedCloudSyncRecord<CloudSyncRecordPayload>] = [:]
        for record in records {
            let key = dedupeKey(id: record.payload.id, ownerUserId: record.payload.ownerUserId, scope: record.scope)
            if let existing = indexed[key], existing.payload.updatedAt >= record.payload.updatedAt {
                continue
            }
            indexed[key] = record
        }
        return Array(indexed.values)
    }

    func dedupeKey(id: UUID, ownerUserId: String, scope: CloudSyncScope) -> String {
        "\(scope.rawCloudValue):\(ownerUserId):\(id.uuidString)"
    }
}

enum CloudKitCloudSyncClientError: LocalizedError, Equatable {
    case missingField(String)
    case invalidField(String)

    var errorDescription: String? {
        switch self {
        case .missingField(let field):
            return "CloudKit record is missing required field: \(field)"
        case .invalidField(let field):
            return "CloudKit record has invalid field: \(field)"
        }
    }
}

private extension CloudSyncScope {
    var rawCloudValue: String {
        switch self {
        case .private:
            return "private"
        case .shared:
            return "shared"
        }
    }
}
#endif
