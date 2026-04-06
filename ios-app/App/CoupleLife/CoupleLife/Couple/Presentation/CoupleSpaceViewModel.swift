import Foundation

@MainActor
final class CoupleSpaceViewModel: ObservableObject {
    @Published private(set) var status = CoupleSpaceStatus(activeSpace: nil)
    @Published private(set) var hasLoadedOnce = false
    @Published private(set) var isLoading = false
    @Published private(set) var isPerformingAction = false
    @Published var errorMessage: String?
    @Published var copiedSpaceID: String?

    private let service: any CoupleSpaceService

    init(service: any CoupleSpaceService) {
        self.service = service
    }

    func load() async {
        isLoading = true
        defer {
            isLoading = false
            hasLoadedOnce = true
        }

        do {
            status = try service.currentStatus()
        } catch {
            errorMessage = resolvedMessage(for: error)
        }
    }

    func createSpace(name: String, anniversaryDate: Date?) async {
        await performAction {
            try service.createSpace(name: name, anniversaryDate: anniversaryDate)
        }
    }

    func joinSpace(id: String) async {
        await performAction {
            try service.joinSpace(id: id)
        }
    }

    func leaveActiveSpace() async {
        await performAction {
            try service.leaveActiveSpace()
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func markCopied(spaceID: String) {
        copiedSpaceID = spaceID
    }

    private func performAction(_ operation: () throws -> CoupleSpaceStatus) async {
        isPerformingAction = true
        defer {
            isPerformingAction = false
            hasLoadedOnce = true
        }

        do {
            status = try operation()
            copiedSpaceID = nil
        } catch {
            errorMessage = resolvedMessage(for: error)
        }
    }

    private func resolvedMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        return "操作未完成，请稍后重试。"
    }
}
