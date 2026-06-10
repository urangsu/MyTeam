import Foundation
import Combine

enum ToolExecutionLogState: String, Codable, Sendable, Equatable {
    case running
    case succeeded
    case failed
    case blocked
}

enum ToolExecutionPath: String, Codable, Sendable, Equatable {
    case toolCard
    case chatFastPath
    case planner
}

struct ToolExecutionLogEntry: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let toolID: String
    let displayName: String
    let permissionLevel: MyTeamPermissionLevel
    let startedAt: Date
    let firstVisibleFeedbackAt: Date?
    let finishedAt: Date?
    let durationMs: Int?
    let state: ToolExecutionLogState
    let provider: ExternalProvider?
    let failureMessage: String?
    let resultSummary: String?
    let timedOut: Bool
    let path: ToolExecutionPath

    enum CodingKeys: String, CodingKey {
        case id, toolID, displayName, permissionLevel, startedAt, firstVisibleFeedbackAt, finishedAt
        case durationMs, state, provider, failureMessage, resultSummary, timedOut, path
    }

    init(
        id: UUID,
        toolID: String,
        displayName: String,
        permissionLevel: MyTeamPermissionLevel,
        startedAt: Date,
        firstVisibleFeedbackAt: Date?,
        finishedAt: Date?,
        durationMs: Int?,
        state: ToolExecutionLogState,
        provider: ExternalProvider?,
        failureMessage: String?,
        resultSummary: String?,
        timedOut: Bool,
        path: ToolExecutionPath
    ) {
        self.id = id
        self.toolID = toolID
        self.displayName = displayName
        self.permissionLevel = permissionLevel
        self.startedAt = startedAt
        self.firstVisibleFeedbackAt = firstVisibleFeedbackAt
        self.finishedAt = finishedAt
        self.durationMs = durationMs
        self.state = state
        self.provider = provider
        self.failureMessage = failureMessage
        self.resultSummary = resultSummary
        self.timedOut = timedOut
        self.path = path
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        toolID = try values.decode(String.self, forKey: .toolID)
        displayName = try values.decode(String.self, forKey: .displayName)
        permissionLevel = try values.decode(MyTeamPermissionLevel.self, forKey: .permissionLevel)
        startedAt = try values.decode(Date.self, forKey: .startedAt)
        firstVisibleFeedbackAt = try values.decodeIfPresent(Date.self, forKey: .firstVisibleFeedbackAt)
        finishedAt = try values.decodeIfPresent(Date.self, forKey: .finishedAt)
        durationMs = try values.decodeIfPresent(Int.self, forKey: .durationMs)
        state = try values.decode(ToolExecutionLogState.self, forKey: .state)
        provider = try values.decodeIfPresent(ExternalProvider.self, forKey: .provider)
        failureMessage = try values.decodeIfPresent(String.self, forKey: .failureMessage)
        resultSummary = try values.decodeIfPresent(String.self, forKey: .resultSummary)
        timedOut = try values.decodeIfPresent(Bool.self, forKey: .timedOut) ?? false
        path = try values.decodeIfPresent(ToolExecutionPath.self, forKey: .path) ?? .toolCard
    }
}

@MainActor
final class ToolExecutionLogStore: ObservableObject {
    static let shared = ToolExecutionLogStore()

    @Published private(set) var entries: [ToolExecutionLogEntry] = []

    // Do not persist raw input, OAuth tokens, API keys, mail bodies, spreadsheet values,
    // calendar details, or external message contents. Store status and short summaries only.
    private let userDefaultsKey = "MyTeam.ToolExecutionLogStore.entries"
    private let maxEntries = 20
    private let maxPersistedTextLength = 160

    private init() {
        entries = loadEntries()
    }

    @discardableResult
    func start(descriptor: MyTeamToolDescriptor, path: ToolExecutionPath = .toolCard) -> UUID {
        let id = UUID()
        let now = Date()
        let entry = ToolExecutionLogEntry(
            id: id,
            toolID: descriptor.id,
            displayName: descriptor.displayName,
            permissionLevel: descriptor.permissionLevel,
            startedAt: now,
            firstVisibleFeedbackAt: now,
            finishedAt: nil,
            durationMs: nil,
            state: .running,
            provider: descriptor.relatedProvider ?? descriptor.requiredCredential?.provider,
            failureMessage: nil,
            resultSummary: nil,
            timedOut: false,
            path: path
        )
        entries.insert(entry, at: 0)
        trimAndPersist()
        return id
    }

    func finish(id: UUID, state: ToolExecutionState) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let existing = entries[index]
        let finishedAt = Date()
        entries[index] = ToolExecutionLogEntry(
            id: existing.id,
            toolID: existing.toolID,
            displayName: existing.displayName,
            permissionLevel: existing.permissionLevel,
            startedAt: existing.startedAt,
            firstVisibleFeedbackAt: existing.firstVisibleFeedbackAt,
            finishedAt: finishedAt,
            durationMs: Int(finishedAt.timeIntervalSince(existing.startedAt) * 1000),
            state: logState(for: state),
            provider: existing.provider,
            failureMessage: failureMessage(for: state),
            resultSummary: resultSummary(for: state),
            timedOut: isTimeout(state),
            path: existing.path
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
        case .needsConnection, .needsAssistantConnection, .needsValidation, .needsApproval, .unavailable:
            return .blocked
        case .idle, .checkingReadiness, .running:
            return .running
        }
    }

    private func failureMessage(for state: ToolExecutionState) -> String? {
        let rawMessage: String?
        switch state {
        case .failed(let failure):
            rawMessage = failure.message
        case .needsConnection(let provider):
            rawMessage = "\(provider.displayName) 연결이 필요합니다."
        case .needsAssistantConnection(let provider):
            rawMessage = "\(provider.displayName) 연결이 필요합니다."
        case .needsValidation(let provider):
            rawMessage = "\(provider.displayName) 검증이 필요합니다."
        case .needsApproval(let reason), .unavailable(let reason):
            rawMessage = reason
        default:
            rawMessage = nil
        }
        return sanitizedPersistedText(rawMessage)
    }

    private func resultSummary(for state: ToolExecutionState) -> String? {
        guard case .succeeded(let result) = state else { return nil }
        return sanitizedPersistedText(result.summary)
    }

    private func isTimeout(_ state: ToolExecutionState) -> Bool {
        switch state {
        case .failed(let failure):
            return failure.message.contains("시간") || failure.title.contains("지연")
        case .unavailable(let reason):
            return reason.contains("시간") || reason.contains("지연")
        default:
            return false
        }
    }

    private func sanitizedPersistedText(_ value: String?) -> String? {
        guard var text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        let sensitivePatterns = [
            #"(?i)(api[_ -]?key|client[_ -]?secret|access[_ -]?token|refresh[_ -]?token|bearer)\s*[:=]\s*[^,\s]+"#,
            #"(?i)Authorization:\s*Bearer\s+[^,\s]+"#,
            #"AIza[0-9A-Za-z\-_]{20,}"#,
            #"[A-Za-z0-9_\-]{24,}\.[A-Za-z0-9_\-]{24,}\.[A-Za-z0-9_\-]{24,}"#
        ]
        for pattern in sensitivePatterns {
            text = text.replacingOccurrences(
                of: pattern,
                with: "[redacted]",
                options: [.regularExpression]
            )
        }
        if text.count > maxPersistedTextLength {
            let end = text.index(text.startIndex, offsetBy: maxPersistedTextLength)
            return String(text[..<end]) + "..."
        }
        return text
    }
}
