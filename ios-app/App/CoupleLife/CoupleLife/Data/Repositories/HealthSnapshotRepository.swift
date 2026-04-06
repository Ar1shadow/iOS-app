import Foundation
import SwiftData

protocol HealthSnapshotRepository {
    func upsert(_ snapshot: HealthMetricSnapshot) throws
    func snapshot(bucket: HealthMetricBucket, start: Date, ownerUserId: String) throws -> HealthMetricSnapshot?
    func snapshot(dayStart: Date, ownerUserId: String) throws -> HealthMetricSnapshot?
    func snapshots(bucket: HealthMetricBucket, from startDate: Date, to endDate: Date, ownerUserId: String) throws -> [HealthMetricSnapshot]
}

final class SwiftDataHealthSnapshotRepository: HealthSnapshotRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func upsert(_ snapshot: HealthMetricSnapshot) throws {
        if let existing = try self.snapshot(bucket: snapshot.bucket, start: snapshot.dayStart, ownerUserId: snapshot.ownerUserId) {
            existing.dayStart = snapshot.dayStart
            existing.bucketRaw = snapshot.bucketRaw
            existing.visibilityRaw = snapshot.visibilityRaw
            existing.sourceRaw = snapshot.sourceRaw

            existing.steps = snapshot.steps
            existing.distanceMeters = snapshot.distanceMeters
            existing.activeEnergyKcal = snapshot.activeEnergyKcal
            existing.exerciseMinutes = snapshot.exerciseMinutes
            existing.standMinutes = snapshot.standMinutes

            existing.restingHeartRate = snapshot.restingHeartRate
            existing.sleepSeconds = snapshot.sleepSeconds

            existing.updatedAt = Date()
            existing.version += 1
        } else {
            context.insert(snapshot)
        }

        try context.save()
    }

    func snapshot(bucket: HealthMetricBucket, start: Date, ownerUserId: String) throws -> HealthMetricSnapshot? {
        let predicate = #Predicate<HealthMetricSnapshot> {
            $0.dayStart == start && $0.bucketRaw == bucket.rawValue && $0.ownerUserId == ownerUserId
        }
        let descriptor = FetchDescriptor<HealthMetricSnapshot>(predicate: predicate)
        return try context.fetch(descriptor).first
    }

    func snapshot(dayStart: Date, ownerUserId: String) throws -> HealthMetricSnapshot? {
        try snapshot(bucket: .day, start: dayStart, ownerUserId: ownerUserId)
    }

    func snapshots(bucket: HealthMetricBucket, from startDate: Date, to endDate: Date, ownerUserId: String) throws -> [HealthMetricSnapshot] {
        let predicate = #Predicate<HealthMetricSnapshot> {
            $0.bucketRaw == bucket.rawValue &&
            $0.ownerUserId == ownerUserId &&
            $0.dayStart >= startDate &&
            $0.dayStart < endDate
        }
        var descriptor = FetchDescriptor<HealthMetricSnapshot>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.dayStart, order: .forward)]
        return try context.fetch(descriptor)
    }
}
