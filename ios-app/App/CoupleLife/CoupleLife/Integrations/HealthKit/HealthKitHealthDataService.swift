import Foundation
import HealthKit

enum HealthKitAuthorizationRequestStatus {
    case shouldRequest
    case unnecessary
    case unknown
}

struct HealthMetricPayload: Equatable {
    let steps: Double?
    let sleepSeconds: Double?
    let restingHeartRate: Double?
}

protocol HealthKitClient {
    var isHealthDataAvailable: Bool { get }
    func requestAuthorizationStatus() async throws -> HealthKitAuthorizationRequestStatus
    func requestAuthorization() async throws
    func readMetrics(from startDate: Date, to endDate: Date) async throws -> HealthMetricPayload
}

@MainActor
final class HealthKitHealthDataService: HealthDataService {
    private let repository: any HealthSnapshotRepository
    private let client: any HealthKitClient
    private let calendar: Calendar
    private let nowProvider: () -> Date

    init(
        repository: any HealthSnapshotRepository,
        client: any HealthKitClient = LiveHealthKitClient(),
        calendar: Calendar = .current,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.client = client
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    func availability() async -> ServiceAvailability {
        await availabilityStatus()
    }

    func requestAuthorization() async -> ServiceAvailability {
        guard client.isHealthDataAvailable else {
            return .notSupported
        }

        do {
            try await client.requestAuthorization()
            return await availabilityStatus()
        } catch HealthKitClientError.authorizationRejected {
            return .notAuthorized
        } catch {
            return .failed("健康权限请求失败，请稍后重试。")
        }
    }

    func refreshTodaySnapshot(ownerUserId: String, asOf date: Date, force: Bool) async -> ServiceAvailability {
        let availability = await availabilityStatus()
        guard availability == .available else {
            return availability
        }

        let dayStart = calendar.startOfDay(for: date)
        if !force, let cachedSnapshot = try? repository.snapshot(dayStart: dayStart, ownerUserId: ownerUserId),
           isSnapshotFresh(cachedSnapshot, for: dayStart) {
            return .available
        }

        do {
            try await refreshSnapshots(ownerUserId: ownerUserId, asOf: date)
            return .available
        } catch {
            return .failed("健康数据刷新失败，请稍后重试。")
        }
    }

    private func availabilityStatus() async -> ServiceAvailability {
        guard client.isHealthDataAvailable else {
            return .notSupported
        }

        do {
            switch try await client.requestAuthorizationStatus() {
            case .shouldRequest:
                return .notAuthorized
            case .unnecessary:
                return .available
            case .unknown:
                return .failed("健康权限状态暂不可用。")
            }
        } catch {
            return .failed("健康服务状态检查失败。")
        }
    }

    private func isSnapshotFresh(_ snapshot: HealthMetricSnapshot, for dayStart: Date) -> Bool {
        snapshot.dayStart == dayStart && calendar.isDate(snapshot.updatedAt, inSameDayAs: nowProvider())
    }

    private func refreshSnapshots(ownerUserId: String, asOf date: Date) async throws {
        for bucket in HealthMetricBucket.allCases {
            let interval = bucketInterval(for: bucket, containing: date)
            let payload = try await client.readMetrics(from: interval.start, to: interval.end)
            let now = nowProvider()
            try repository.upsert(
                HealthMetricSnapshot(
                    dayStart: interval.start,
                    ownerUserId: ownerUserId,
                    bucket: bucket,
                    source: .healthKit,
                    steps: payload.steps,
                    restingHeartRate: payload.restingHeartRate,
                    sleepSeconds: payload.sleepSeconds,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }
    }

    private func bucketInterval(for bucket: HealthMetricBucket, containing date: Date) -> DateInterval {
        switch bucket {
        case .day:
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, end: date)
        case .month:
            return calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, end: date)
        }
    }

}

private enum HealthKitClientError: Error {
    case authorizationRejected
}

private final class LiveHealthKitClient: HealthKitClient {
    private let store = HKHealthStore()

    var isHealthDataAvailable: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        HKHealthStore.isHealthDataAvailable()
        #endif
    }

    func requestAuthorizationStatus() async throws -> HealthKitAuthorizationRequestStatus {
        try await withCheckedThrowingContinuation { continuation in
            store.getRequestStatusForAuthorization(toShare: [], read: Self.readTypes) { status, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: Self.map(status))
            }
        }
    }

    func requestAuthorization() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: [], read: Self.readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard success else {
                    continuation.resume(throwing: HealthKitClientError.authorizationRejected)
                    return
                }

                continuation.resume(returning: ())
            }
        }
    }

    func readMetrics(from startDate: Date, to endDate: Date) async throws -> HealthMetricPayload {
        async let steps = readStepCount(from: startDate, to: endDate)
        async let sleepSeconds = readSleepDuration(from: startDate, to: endDate)
        async let restingHeartRate = readRestingHeartRate(from: startDate, to: endDate)

        return try await HealthMetricPayload(
            steps: steps,
            sleepSeconds: sleepSeconds,
            restingHeartRate: restingHeartRate
        )
    }

    private func readStepCount(from startDate: Date, to endDate: Date) async throws -> Double? {
        let quantityType = Self.stepCountType
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let value = statistics?.sumQuantity()?.doubleValue(for: HKUnit.count())
                continuation.resume(returning: value)
            }

            store.execute(query)
        }
    }

    private func readSleepDuration(from startDate: Date, to endDate: Date) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: Self.sleepAnalysisType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let total = (samples as? [HKCategorySample])?.reduce(0.0) { partialResult, sample in
                    guard Self.isAsleep(sample.value) else {
                        return partialResult
                    }

                    let overlapStart = max(sample.startDate, startDate)
                    let overlapEnd = min(sample.endDate, endDate)
                    guard overlapEnd > overlapStart else {
                        return partialResult
                    }

                    return partialResult + overlapEnd.timeIntervalSince(overlapStart)
                }

                continuation.resume(returning: total)
            }

            store.execute(query)
        }
    }

    private func readRestingHeartRate(from startDate: Date, to endDate: Date) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: Self.restingHeartRateType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let value = statistics?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: value)
            }

            store.execute(query)
        }
    }

    private static var readTypes: Set<HKObjectType> {
        [stepCountType, sleepAnalysisType, restingHeartRateType]
    }

    private static var stepCountType: HKQuantityType {
        HKObjectType.quantityType(forIdentifier: .stepCount)!
    }

    private static var sleepAnalysisType: HKCategoryType {
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    }

    private static var restingHeartRateType: HKQuantityType {
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
    }

    private static func map(_ status: HKAuthorizationRequestStatus) -> HealthKitAuthorizationRequestStatus {
        switch status {
        case .shouldRequest:
            return .shouldRequest
        case .unnecessary:
            return .unnecessary
        case .unknown:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    private static func isAsleep(_ rawValue: Int) -> Bool {
        guard let value = HKCategoryValueSleepAnalysis(rawValue: rawValue) else {
            return false
        }

        switch value {
        case .inBed, .awake:
            return false
        case .asleep, .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM:
            return true
        @unknown default:
            return false
        }
    }
}
