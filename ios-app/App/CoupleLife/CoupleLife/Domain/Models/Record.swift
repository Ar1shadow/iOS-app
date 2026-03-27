import Foundation
import SwiftData

@Model
final class Record {
    @Attribute(.unique) var id: UUID

    var typeRaw: String
    var note: String?

    var startAt: Date
    var endAt: Date?

    var ownerUserId: String
    var coupleSpaceId: String?
    var visibilityRaw: String
    var sourceRaw: String

    var createdAt: Date
    var updatedAt: Date
    var version: Int

    init(
        id: UUID = UUID(),
        type: RecordType,
        note: String? = nil,
        startAt: Date,
        endAt: Date? = nil,
        ownerUserId: String,
        coupleSpaceId: String? = nil,
        visibility: Visibility = .private,
        source: DataSource = .manual,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.note = note
        self.startAt = startAt
        self.endAt = endAt
        self.ownerUserId = ownerUserId
        self.coupleSpaceId = coupleSpaceId
        self.visibilityRaw = visibility.rawValue
        self.sourceRaw = source.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
    }

    var type: RecordType {
        get { RecordType(rawValue: typeRaw) ?? .custom }
        set { typeRaw = newValue.rawValue }
    }

    var visibility: Visibility {
        get { Visibility(rawValue: visibilityRaw) ?? .private }
        set { visibilityRaw = newValue.rawValue }
    }

    var source: DataSource {
        get { DataSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
}

