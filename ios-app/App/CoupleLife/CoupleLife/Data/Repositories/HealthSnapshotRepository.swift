import Foundation
import SwiftData

protocol HealthSnapshotRepository {
    func upsert(_ snapshot: HealthMetricSnapshot) throws
    func snapshot(dayStart: Date, ownerUserId: String) throws -> HealthMetricSnapshot?
}

final class SwiftDataHealthSnapshotRepository: HealthSnapshotRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func upsert(_ snapshot: HealthMetricSnapshot) throws {
        if let existing = try self.snapshot(dayStart: snapshot.dayStart, ownerUserId: snapshot.ownerUserId) {
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

    func snapshot(dayStart: Date, ownerUserId: String) throws -> HealthMetricSnapshot? {
        let predicate = #Predicate<HealthMetricSnapshot> { $0.dayStart == dayStart && $0.ownerUserId == ownerUserId }
        let descriptor = FetchDescriptor<HealthMetricSnapshot>(predicate: predicate)
        return try context.fetch(descriptor).first
    }
}

