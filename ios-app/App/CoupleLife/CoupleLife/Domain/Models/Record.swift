import Foundation
import SwiftData

@Model
final class Record {
    @Attribute(.unique) var id: UUID

    var typeRaw: String
    var note: String?
    var tagsRaw: String
    var valueText: String?

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
        tagsRaw: String = "",
        startAt: Date,
        endAt: Date? = nil,
        valueText: String? = nil,
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
        self.tagsRaw = Self.normalizedTagsRaw(from: tagsRaw)
        self.valueText = valueText?.trimmedNilIfEmpty
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

    var tags: [String] {
        get {
            tagsRaw
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            tagsRaw = Self.normalizedTagsRaw(from: newValue.joined(separator: ","))
        }
    }

    private static func normalizedTagsRaw(from rawValue: String) -> String {
        rawValue
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ",")
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
