import EventKit
import Foundation

final class EventKitCalendarSyncService: CalendarSyncService {
    private let eventStore: EKEventStore
    private let calendar: Calendar

    init(
        eventStore: EKEventStore = EKEventStore(),
        calendar: Calendar = .current
    ) {
        self.eventStore = eventStore
        self.calendar = calendar
    }

    func availability() async -> ServiceAvailability {
        currentAvailability()
    }

    func currentAvailability() -> ServiceAvailability {
        switch authorizationStatus {
        case .fullAccess, .writeOnly:
            return .available
        case .notDetermined, .denied, .restricted:
            return .notAuthorized
        @unknown default:
            return .failed("系统日历权限状态未知。")
        }
    }

    func requestAccess() async -> ServiceAvailability {
        let initialAvailability = currentAvailability()
        if initialAvailability == .available {
            return initialAvailability
        }

        guard authorizationStatus == .notDetermined else {
            return initialAvailability
        }

        do {
            // The app only needs to create and delete its own events, so write-only access is sufficient.
            let granted = try await eventStore.requestWriteOnlyAccessToEvents()
            return granted ? .available : .notAuthorized
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func upsertEvent(for task: TaskItem) throws -> String {
        let availability = currentAvailability()
        guard availability == .available else {
            throw CalendarSyncError.unavailable(availability)
        }

        let event = if let identifier = task.systemCalendarEventId,
                       let existingEvent = eventStore.event(withIdentifier: identifier) {
            existingEvent
        } else {
            EKEvent(eventStore: eventStore)
        }

        guard let targetCalendar = event.calendar ?? eventStore.defaultCalendarForNewEvents else {
            throw CalendarSyncError.operationFailed("未找到可写入的系统日历。")
        }

        let dateRange = try makeDateRange(for: task)
        event.calendar = targetCalendar
        event.title = task.title
        event.notes = makeNotes(for: task)
        event.isAllDay = task.isAllDay
        event.startDate = dateRange.start
        event.endDate = dateRange.end

        do {
            try eventStore.save(event, span: .thisEvent)
            guard let eventIdentifier = event.eventIdentifier else {
                throw CalendarSyncError.operationFailed("系统日历事件标识未生成。")
            }
            return eventIdentifier
        } catch let syncError as CalendarSyncError {
            throw syncError
        } catch {
            throw CalendarSyncError.operationFailed(error.localizedDescription)
        }
    }

    func deleteEvent(withIdentifier identifier: String) throws {
        let availability = currentAvailability()
        guard availability == .available else {
            throw CalendarSyncError.unavailable(availability)
        }

        guard let event = eventStore.event(withIdentifier: identifier) else {
            return
        }

        do {
            try eventStore.remove(event, span: .thisEvent)
        } catch {
            throw CalendarSyncError.operationFailed(error.localizedDescription)
        }
    }

    private var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    private func makeDateRange(for task: TaskItem) throws -> DateInterval {
        if task.isAllDay {
            guard let anchorDate = task.startAt ?? task.dueAt else {
                throw CalendarSyncError.operationFailed("未排期任务不会写入系统日历。")
            }

            let start = calendar.startOfDay(for: anchorDate)
            let endBase = task.dueAt ?? anchorDate
            let inclusiveEnd = calendar.startOfDay(for: endBase)
            let end = calendar.date(byAdding: .day, value: 1, to: inclusiveEnd) ?? inclusiveEnd
            return DateInterval(start: start, end: max(end, start.addingTimeInterval(86_400)))
        }

        guard let start = task.startAt ?? task.dueAt else {
            throw CalendarSyncError.operationFailed("未排期任务不会写入系统日历。")
        }

        if let dueAt = task.dueAt, dueAt > start {
            return DateInterval(start: start, end: dueAt)
        }

        return DateInterval(start: start, end: start.addingTimeInterval(3_600))
    }

    private func makeNotes(for task: TaskItem) -> String? {
        let detail = task.detail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let statusLine = "状态：\(task.status.title)"

        switch detail {
        case .some(let detail) where !detail.isEmpty:
            return "\(detail)\n\n\(statusLine)"
        default:
            return statusLine
        }
    }
}
