import Foundation
import SwiftData

@Model
final class HealthMetricSnapshot {
    @Attribute(.unique) var id: UUID

    var dayStart: Date
    var bucketRaw: String
    var ownerUserId: String
    var coupleSpaceId: String?
    var visibilityRaw: String
    var sourceRaw: String

    var steps: Double?
    var distanceMeters: Double?
    var activeEnergyKcal: Double?
    var exerciseMinutes: Double?
    var standMinutes: Double?

    var restingHeartRate: Double?
    var sleepSeconds: Double?

    var createdAt: Date
    var updatedAt: Date
    var version: Int

    init(
        id: UUID = UUID(),
        dayStart: Date,
        ownerUserId: String,
        bucket: HealthMetricBucket = .day,
        coupleSpaceId: String? = nil,
        visibility: Visibility = .private,
        source: DataSource = .healthKit,
        steps: Double? = nil,
        distanceMeters: Double? = nil,
        activeEnergyKcal: Double? = nil,
        exerciseMinutes: Double? = nil,
        standMinutes: Double? = nil,
        restingHeartRate: Double? = nil,
        sleepSeconds: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1
    ) {
        self.id = id
        self.dayStart = dayStart
        self.bucketRaw = bucket.rawValue
        self.ownerUserId = ownerUserId
        self.coupleSpaceId = coupleSpaceId
        self.visibilityRaw = visibility.rawValue
        self.sourceRaw = source.rawValue
        self.steps = steps
        self.distanceMeters = distanceMeters
        self.activeEnergyKcal = activeEnergyKcal
        self.exerciseMinutes = exerciseMinutes
        self.standMinutes = standMinutes
        self.restingHeartRate = restingHeartRate
        self.sleepSeconds = sleepSeconds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
    }

    var visibility: Visibility {
        get { Visibility(rawValue: visibilityRaw) ?? .private }
        set { visibilityRaw = newValue.rawValue }
    }

    var bucket: HealthMetricBucket {
        get { HealthMetricBucket(rawValue: bucketRaw) ?? .day }
        set { bucketRaw = newValue.rawValue }
    }

    var source: DataSource {
        get { DataSource(rawValue: sourceRaw) ?? .healthKit }
        set { sourceRaw = newValue.rawValue }
    }
}
