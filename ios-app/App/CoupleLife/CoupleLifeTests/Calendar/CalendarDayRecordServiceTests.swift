import XCTest
@testable import CoupleLife

final class CalendarDayRecordServiceTests: XCTestCase {
    func testQuickCheckInUsesNowWhenSelectedDayIsToday() throws {
        let calendar = fixedCalendar()
        let now = makeDate(year: 2026, month: 3, day: 28, hour: 9, minute: 15, calendar: calendar)
        let repository = InMemoryRecordRepository()
        let service = DefaultCalendarDayRecordService(
            recordRepository: repository,
            calendar: calendar,
            ownerUserId: "local",
            nowProvider: { now }
        )

        let created = try service.createQuickCheckIn(type: .water, on: now)

        XCTAssertEqual(created.type, .water)
        XCTAssertEqual(created.startAt, now)
        XCTAssertEqual(repository.storedRecords.first?.startAt, now)
        XCTAssertEqual(repository.storedRecords.first?.visibility, .private)
    }

    func testQuickCheckInUsesNoonForNonToday() throws {
        let calendar = fixedCalendar()
        let now = makeDate(year: 2026, month: 3, day: 28, hour: 9, minute: 15, calendar: calendar)
        let selectedDay = makeDate(year: 2026, month: 3, day: 30, hour: 0, minute: 0, calendar: calendar)
        let repository = InMemoryRecordRepository()
        let service = DefaultCalendarDayRecordService(
            recordRepository: repository,
            calendar: calendar,
            ownerUserId: "local",
            nowProvider: { now }
        )

        let created = try service.createQuickCheckIn(type: .bowelMovement, on: selectedDay)

        XCTAssertEqual(created.type, .bowelMovement)
        XCTAssertEqual(created.startAt, makeDate(year: 2026, month: 3, day: 30, hour: 12, minute: 0, calendar: calendar))
        XCTAssertEqual(repository.storedRecords.count, 1)
    }

    func testCreateRecordRejectsEndBeforeStart() {
        let calendar = fixedCalendar()
        let now = makeDate(year: 2026, month: 3, day: 28, hour: 9, minute: 15, calendar: calendar)
        let repository = InMemoryRecordRepository()
        let service = DefaultCalendarDayRecordService(
            recordRepository: repository,
            calendar: calendar,
            ownerUserId: "local",
            nowProvider: { now }
        )

        var draft = service.makeDraft(for: now)
        draft.endAt = draft.startAt.addingTimeInterval(-60)

        XCTAssertThrowsError(try service.createRecord(from: draft)) { error in
            XCTAssertEqual(error as? CalendarDayRecordValidationError, .endBeforeStart)
        }
        XCTAssertTrue(repository.storedRecords.isEmpty)
    }

    func testUpdateRecordPreservesNonManualSourceWhenDraftCarriesOriginalSource() throws {
        let calendar = fixedCalendar()
        let now = makeDate(year: 2026, month: 3, day: 28, hour: 9, minute: 15, calendar: calendar)
        let repository = InMemoryRecordRepository()
        let service = DefaultCalendarDayRecordService(
            recordRepository: repository,
            calendar: calendar,
            ownerUserId: "local",
            nowProvider: { now }
        )

        let record = Record(
            type: .water,
            note: "Original",
            startAt: now,
            ownerUserId: "local",
            source: .healthKit
        )
        try repository.create(record)

        var draft = service.makeDraft(for: record)
        draft.note = "Edited note"

        try service.updateRecord(record, from: draft)

        XCTAssertEqual(repository.storedRecords.first?.note, "Edited note")
        XCTAssertEqual(repository.storedRecords.first?.source, .healthKit)
    }

    func testCreateRecordSanitizesUnsupportedSummaryVisibilityForNonSensitiveType() throws {
        let calendar = fixedCalendar()
        let now = makeDate(year: 2026, month: 3, day: 28, hour: 9, minute: 15, calendar: calendar)
        let repository = InMemoryRecordRepository()
        let service = DefaultCalendarDayRecordService(
            recordRepository: repository,
            calendar: calendar,
            ownerUserId: "local",
            nowProvider: { now }
        )

        let draft = CalendarDayRecordDraft(
            type: .water,
            startAt: now,
            visibility: .summaryShared
        )

        let created = try service.createRecord(from: draft)

        XCTAssertEqual(created.visibility, .private)
        XCTAssertEqual(repository.storedRecords.first?.visibility, .private)
    }

    func testUpdateRecordSanitizesUnsupportedSummaryVisibilityWhenTypeChangesToNonSensitive() throws {
        let calendar = fixedCalendar()
        let now = makeDate(year: 2026, month: 3, day: 28, hour: 9, minute: 15, calendar: calendar)
        let repository = InMemoryRecordRepository()
        let service = DefaultCalendarDayRecordService(
            recordRepository: repository,
            calendar: calendar,
            ownerUserId: "local",
            nowProvider: { now }
        )

        let record = Record(
            type: .menstruation,
            startAt: now,
            ownerUserId: "local",
            visibility: .summaryShared
        )
        try repository.create(record)

        let draft = CalendarDayRecordDraft(
            type: .water,
            startAt: now,
            visibility: .summaryShared
        )

        try service.updateRecord(record, from: draft)

        XCTAssertEqual(record.visibility, .private)
        XCTAssertEqual(repository.storedRecords.first?.visibility, .private)
    }

    private func fixedCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int, calendar: Calendar) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ).date!
    }
}

private final class InMemoryRecordRepository: RecordRepository {
    private(set) var storedRecords: [Record] = []

    func create(_ record: Record) throws {
        storedRecords.append(record)
    }

    func update(_ record: Record) throws {
        if let index = storedRecords.firstIndex(where: { $0.id == record.id }) {
            storedRecords[index] = record
        }
    }

    func delete(_ record: Record) throws {
        storedRecords.removeAll { $0.id == record.id }
    }

    func records(from start: Date, to end: Date) throws -> [Record] {
        storedRecords.filter { $0.startAt >= start && $0.startAt < end }
    }
}
