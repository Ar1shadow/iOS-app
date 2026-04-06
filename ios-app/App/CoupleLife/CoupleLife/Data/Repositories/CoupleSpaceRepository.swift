import Foundation
import SwiftData

protocol CoupleSpaceRepository {
    func create(_ coupleSpace: CoupleSpace) throws
    func fetch(id: String) throws -> CoupleSpace?
    func delete(_ coupleSpace: CoupleSpace) throws
}

final class SwiftDataCoupleSpaceRepository: CoupleSpaceRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func create(_ coupleSpace: CoupleSpace) throws {
        context.insert(coupleSpace)
    }

    func fetch(id: String) throws -> CoupleSpace? {
        let predicate = #Predicate<CoupleSpace> { $0.id == id }
        let descriptor = FetchDescriptor<CoupleSpace>(predicate: predicate)
        return try context.fetch(descriptor).first
    }

    func delete(_ coupleSpace: CoupleSpace) throws {
        context.delete(coupleSpace)
    }
}
