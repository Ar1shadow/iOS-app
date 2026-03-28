import Foundation
@testable import CoupleLife

final class TestCalendarSyncSettingsStore: CalendarSyncSettingsStore {
    var isEnabled: Bool

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
}

final class TestCalendarSyncService: CalendarSyncService {
    enum Operation: Equatable {
        case deleteEvent(String)
        case deleteTask(UUID)
    }

    var currentServiceAvailability: ServiceAvailability = .available
    var upsertedEventIdentifier: String = "event-id"
    var upsertError: Error?
    var deleteError: Error?
    var upsertedTaskTitles: [String] = []
    var deletedEventIdentifiers: [String] = []
    var operationLog: [Operation] = []

    func availability() async -> ServiceAvailability {
        currentServiceAvailability
    }

    func currentAvailability() -> ServiceAvailability {
        currentServiceAvailability
    }

    func requestAccess() async -> ServiceAvailability {
        currentServiceAvailability
    }

    func upsertEvent(for task: TaskItem) throws -> String {
        upsertedTaskTitles.append(task.title)
        if let upsertError {
            throw upsertError
        }
        return upsertedEventIdentifier
    }

    func deleteEvent(withIdentifier identifier: String) throws {
        deletedEventIdentifiers.append(identifier)
        operationLog.append(.deleteEvent(identifier))
        if let deleteError {
            throw deleteError
        }
    }
}
