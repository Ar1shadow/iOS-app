import Foundation
import SwiftData

@Model
final class CoupleSpace {
    @Attribute(.unique) var id: String

    var name: String
    var anniversaryDate: Date?

    var createdAt: Date
    var updatedAt: Date
    var version: Int

    init(
        id: String,
        name: String,
        anniversaryDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1
    ) {
        self.id = id
        self.name = name
        self.anniversaryDate = anniversaryDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
    }
}
