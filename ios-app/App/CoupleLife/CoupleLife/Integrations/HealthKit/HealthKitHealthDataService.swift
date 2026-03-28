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
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let payload = try await client.readMetrics(from: dayStart, to: dayEnd)
            let snapshot = HealthMetricSnapshot(
                dayStart: dayStart,
                ownerUserId: ownerUserId,
                source: .healthKit,
                steps: payload.steps,
                sleepSeconds: payload.sleepSeconds,
                createdAt: nowProvider(),
                updatedAt: nowProvider()
            )
            try repository.upsert(snapshot)
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

        return try await HealthMetricPayload(
            steps: steps,
            sleepSeconds: sleepSeconds
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

    private static var readTypes: Set<HKObjectType> {
        [stepCountType, sleepAnalysisType]
    }

    private static var stepCountType: HKQuantityType {
        HKObjectType.quantityType(forIdentifier: .stepCount)!
    }

    private static var sleepAnalysisType: HKCategoryType {
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
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
