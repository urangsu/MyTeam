import Foundation
import Combine

enum ToolExecutionLogState: String, Codable, Sendable, Equatable {
    case running
    case succeeded
    case checkedEmpty
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
    let artifactID: String?
    let artifactFilename: String?
    let timedOut: Bool
    let path: ToolExecutionPath

    enum CodingKeys: String, CodingKey {
        case id, toolID, displayName, permissionLevel, startedAt, firstVisibleFeedbackAt, finishedAt
        case durationMs, state, provider, failureMessage, resultSummary, artifactID, artifactFilename, timedOut, path
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
        artifactID: String?,
        artifactFilename: String?,
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
        self.artifactID = artifactID
        self.artifactFilename = artifactFilename
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
        artifactID = try values.decodeIfPresent(String.self, forKey: .artifactID)
        artifactFilename = try values.decodeIfPresent(String.self, forKey: .artifactFilename)
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
            provider: descriptor.relatedProvider ?? descriptor.requiredCredential?.provider.externalProvider,
            failureMessage: nil,
            resultSummary: nil,
            artifactID: nil,
            artifactFilename: nil,
            timedOut: false,
            path: path
        )
        entries.insert(entry, at: 0)
        trimAndPersist()
        return id
    }

    func finish(id: UUID, state: ToolExecutionState, artifact: IndexedArtifact? = nil) {
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
            artifactID: artifact?.id ?? existing.artifactID,
            artifactFilename: artifact?.filename ?? existing.artifactFilename,
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
        case .succeeded, .partial:
            return .succeeded
        case .checkedEmpty:
            return .checkedEmpty
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
        let result: MyTeamToolResult
        switch state {
        case .succeeded(let value), .checkedEmpty(let value), .partial(let value):
            result = value
        default:
            return nil
        }
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

enum ToolResultArtifactWriter {
    static func write(
        descriptor: MyTeamToolDescriptor,
        result: MyTeamToolResult,
        input: MyTeamToolInput
    ) async -> IndexedArtifact? {
        let markdown = markdownBody(descriptor: descriptor, result: result, input: input)
        let filename = filename(for: descriptor)
        let store = ArtifactStore.shared
        let fileURL = store.workspaceURL.appendingPathComponent(filename)

        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            AppLog.warning("[ToolResultArtifactWriter] artifact write failed: \(error.localizedDescription)")
            return nil
        }

        let now = Date()
        let roomID = await MainActor.run { AgentWindowManager.shared.currentRoomID }
        let workflowID = await MainActor.run { AgentWindowManager.shared.currentWorkflowID } ?? UUID()
        let artifact = IndexedArtifact(
            id: UUID().uuidString,
            workflowID: workflowID.uuidString,
            title: result.title,
            type: artifactType(for: descriptor),
            filename: filename,
            relativePath: filename,
            preview: String(result.summary.prefix(200)),
            createdAt: ISO8601DateFormatter().string(from: now),
            contentHash: StableContentHash.sha256Hex(markdown),
            fileSizeBytes: Int64(markdown.utf8.count),
            roomID: roomID?.uuidString
        )
        await store.registerArtifact(artifact)

        if let roomID {
            await MainActor.run {
                let entry = RecentArtifactIndexEntry(
                    artifactID: artifact.id,
                    roomID: roomID,
                    filename: filename,
                    artifactType: artifact.type.rawValue,
                    createdAt: now,
                    contentHash: artifact.contentHash,
                    fileSizeBytes: artifact.fileSizeBytes
                )
                AgentWindowManager.shared.addRecentArtifactIndexEntry(entry)
            }
        }

        return artifact
    }

    private static func markdownBody(
        descriptor: MyTeamToolDescriptor,
        result: MyTeamToolResult,
        input: MyTeamToolInput
    ) -> String {
        var lines: [String] = [
            "# \(result.title)",
            "",
            "## 요약",
            result.summary,
            "",
            "## 실행 정보",
            "- 업무: \(descriptor.displayName)",
            "- 입력: \(sanitizedInput(input.query))",
            "- 근거: \(result.sourceLabel ?? "MyTeam")"
        ]

        if let body = result.body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
            lines.append("")
            lines.append("## 내용")
            lines.append(body)
        }

        if !result.items.isEmpty {
            lines.append("")
            lines.append("## 근거와 항목")
            for item in result.items {
                lines.append("- \(item.title)")
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    lines.append("  - 설명: \(subtitle)")
                }
                if let metadata = item.metadata, !metadata.isEmpty {
                    lines.append("  - 메타: \(metadata)")
                }
                if let url = item.sourceURL {
                    lines.append("  - 출처: \(url.absoluteString)")
                }
            }
        }

        lines.append("")
        lines.append("## 보고 문장")
        lines.append(reportSentence(for: descriptor, result: result))

        if descriptor.id.hasPrefix("finance.") {
            lines.append("")
            lines.append("> 이 금융 정보는 공공데이터포털 기준일 데이터입니다. 실시간 시세나 투자 조언이 아닙니다.")
        }
        if descriptor.id == "law.search" {
            lines.append("")
            lines.append("> 이 법령 정보는 공식 출처 확인용이며 법률 자문이 아닙니다.")
        }

        return lines.joined(separator: "\n")
    }

    private static func reportSentence(for descriptor: MyTeamToolDescriptor, result: MyTeamToolResult) -> String {
        switch descriptor.category {
        case .externalInfo:
            return "\(descriptor.displayName) 결과는 \(result.sourceLabel ?? "공식 출처") 기준으로 확인되며, \(result.summary)"
        case .calendar:
            return "오늘 일정 확인 결과, \(result.summary)"
        case .spreadsheet:
            return "스프레드시트 확인 결과, \(result.summary)"
        default:
            return result.summary
        }
    }

    private static func filename(for descriptor: MyTeamToolDescriptor) -> String {
        let timestamp = ISO8601DateFormatter()
            .string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let slug = descriptor.id
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        return "tool-result-\(slug)-\(timestamp).md"
    }

    private static func sanitizedInput(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty { return "입력 없음" }
        if trimmed.count > 160 {
            let end = trimmed.index(trimmed.startIndex, offsetBy: 160)
            return String(trimmed[..<end]) + "..."
        }
        return trimmed
    }

    private static func artifactType(for descriptor: MyTeamToolDescriptor) -> ArtifactType {
        switch descriptor.category {
        case .spreadsheet:
            return .spreadsheet
        case .externalInfo, .briefing, .calendar:
            return .report
        case .document:
            return .text
        default:
            return .text
        }
    }
}
