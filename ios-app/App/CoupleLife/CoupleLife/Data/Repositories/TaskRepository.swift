import Foundation
import SwiftData

protocol TaskRepository {
    func create(_ task: TaskItem) throws
    func delete(_ task: TaskItem) throws
    func tasks(status: TaskStatus?) throws -> [TaskItem]
}

final class SwiftDataTaskRepository: TaskRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func create(_ task: TaskItem) throws {
        context.insert(task)
        try context.save()
    }

    func delete(_ task: TaskItem) throws {
        context.delete(task)
        try context.save()
    }

    func tasks(status: TaskStatus?) throws -> [TaskItem] {
        if let status {
            let predicate = #Predicate<TaskItem> { $0.statusRaw == status.rawValue }
            let descriptor = FetchDescriptor<TaskItem>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            return try context.fetch(descriptor)
        }

        let descriptor = FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return try context.fetch(descriptor)
    }
}
