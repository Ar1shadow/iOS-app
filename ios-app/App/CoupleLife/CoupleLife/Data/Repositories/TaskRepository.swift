import Foundation
import SwiftData

protocol TaskRepository {
    func create(_ task: TaskItem) throws
    func delete(_ task: TaskItem) throws
    func tasks(status: TaskStatus?) throws -> [TaskItem]
    func tasks(scheduledFrom start: Date, to end: Date, ownerUserId: String, status: TaskStatus?) throws -> [TaskItem]
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

    func tasks(scheduledFrom start: Date, to end: Date, ownerUserId: String, status: TaskStatus?) throws -> [TaskItem] {
        // SwiftData's #Predicate has sharp edges around Optional<Date> range queries.
        // For MVP, we fetch by owner/status in SwiftData, then apply the time-window filter in memory.
        // If this becomes hot, we can revisit with a dedicated indexed field or a more predicate-friendly model.
        let predicate: Predicate<TaskItem>
        if let status {
            predicate = #Predicate<TaskItem> { task in
                task.ownerUserId == ownerUserId && task.statusRaw == status.rawValue
            }
        } else {
            predicate = #Predicate<TaskItem> { task in
                task.ownerUserId == ownerUserId
            }
        }

        let descriptor = FetchDescriptor<TaskItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        return try context.fetch(descriptor).filter { task in
            let targetDate = task.dueAt ?? task.startAt
            guard let targetDate else { return false }
            return targetDate >= start && targetDate < end
        }
    }
}
