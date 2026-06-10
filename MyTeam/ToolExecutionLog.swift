import Foundation
import Combine

enum ToolExecutionLogState: String, Codable, Sendable, Equatable {
    case running
    case succeeded
    case failed
    case blocked
}

struct ToolExecutionLogEntry: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let toolID: String
    let displayName: String
    let permissionLevel: MyTeamPermissionLevel
    let startedAt: Date
    let finishedAt: Date?
    let state: ToolExecutionLogState
    let provider: ExternalProvider?
    let failureMessage: String?
    let resultSummary: String?
}

@MainActor
final class ToolExecutionLogStore: ObservableObject {
    static let shared = ToolExecutionLogStore()

    @Published private(set) var entries: [ToolExecutionLogEntry] = []

    private let userDefaultsKey = "MyTeam.ToolExecutionLogStore.entries"
    private let maxEntries = 20

    private init() {
        entries = loadEntries()
    }

    @discardableResult
    func start(descriptor: MyTeamToolDescriptor) -> UUID {
        let id = UUID()
        let entry = ToolExecutionLogEntry(
            id: id,
            toolID: descriptor.id,
            displayName: descriptor.displayName,
            permissionLevel: descriptor.permissionLevel,
            startedAt: Date(),
            finishedAt: nil,
            state: .running,
            provider: descriptor.relatedProvider ?? descriptor.requiredCredential?.provider,
            failureMessage: nil,
            resultSummary: nil
        )
        entries.insert(entry, at: 0)
        trimAndPersist()
        return id
    }

    func finish(id: UUID, state: ToolExecutionState) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let existing = entries[index]
        entries[index] = ToolExecutionLogEntry(
            id: existing.id,
            toolID: existing.toolID,
            displayName: existing.displayName,
            permissionLevel: existing.permissionLevel,
            startedAt: existing.startedAt,
            finishedAt: Date(),
            state: logState(for: state),
            provider: existing.provider,
            failureMessage: failureMessage(for: state),
            resultSummary: resultSummary(for: state)
        )
        trimAndPersist()
    }

    func clear() {
        entries.removeAll()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    private func trimAndPersist() {
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    private func loadEntries() -> [ToolExecutionLogEntry] {
        guard
            let data = UserDefaults.standard.data(forKey: userDefaultsKey),
            let decoded = try? JSONDecoder().decode([ToolExecutionLogEntry].self, from: data)
        else {
            return []
        }
        return Array(decoded.prefix(maxEntries))
    }

    private func logState(for state: ToolExecutionState) -> ToolExecutionLogState {
        switch state {
        case .succeeded:
            return .succeeded
        case .failed:
            return .failed
        case .needsConnection, .needsValidation, .needsApproval, .unavailable:
            return .blocked
        case .idle, .checkingReadiness, .running:
            return .running
        }
    }

    private func failureMessage(for state: ToolExecutionState) -> String? {
        switch state {
        case .failed(let failure):
            return failure.message
        case .needsConnection(let provider):
            return "\(provider.displayName) 연결이 필요합니다."
        case .needsValidation(let provider):
            return "\(provider.displayName) 검증이 필요합니다."
        case .needsApproval(let reason), .unavailable(let reason):
            return reason
        default:
            return nil
        }
    }

    private func resultSummary(for state: ToolExecutionState) -> String? {
        guard case .succeeded(let result) = state else { return nil }
        return result.summary
    }
}
