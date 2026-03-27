import Foundation
import SwiftData

protocol RecordRepository {
    func create(_ record: Record) throws
    func delete(_ record: Record) throws
    func records(from start: Date, to end: Date) throws -> [Record]
}

final class SwiftDataRecordRepository: RecordRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func create(_ record: Record) throws {
        context.insert(record)
        try context.save()
    }

    func delete(_ record: Record) throws {
        context.delete(record)
        try context.save()
    }

    func records(from start: Date, to end: Date) throws -> [Record] {
        let predicate = #Predicate<Record> { $0.startAt >= start && $0.startAt < end }
        let descriptor = FetchDescriptor<Record>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }
}

