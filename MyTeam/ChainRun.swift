import Foundation

struct ChainSourceReference: Identifiable, Codable, Sendable, Hashable {
    var id: UUID = UUID()
    let title: String
    let provider: String
    let url: String
    let accessedAt: Date
}

struct ChainRun: Identifiable, Codable, Sendable {
    let id: UUID
    let roomID: UUID
    let chainID: SkillChainID
    var steps: [ChainStep]
    var status: ChainStatus
    var sources: [ChainSourceReference]
    var actions: [ActionSuggestion]
    var artifacts: [String]
    var startedAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        roomID: UUID,
        chainID: SkillChainID,
        steps: [ChainStep],
        status: ChainStatus = .running,
        sources: [ChainSourceReference] = [],
        actions: [ActionSuggestion] = [],
        artifacts: [String] = [],
        startedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.roomID = roomID
        self.chainID = chainID
        self.steps = steps
        self.status = status
        self.sources = sources
        self.actions = actions
        self.artifacts = artifacts
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }

    var stepStatusLines: [String] {
        steps.enumerated().map { index, step in
            let prefix: String
            switch step.status {
            case .pending:
                prefix = "·"
            case .running:
                prefix = "▶"
            case .succeeded:
                prefix = "✓"
            case .failed:
                prefix = "✕"
            case .skipped:
                prefix = "↷"
            }
            return "\(index + 1). \(prefix) \(step.title) [\(step.status.label)]"
        }
    }

    var statusSummary: String {
        switch status {
        case .pending:
            return "대기"
        case .running:
            return "실행 중"
        case .succeeded:
            return "성공"
        case .failed:
            return "실패"
        case .blocked:
            return "차단"
        }
    }

    var sourceSummary: String {
        guard !sources.isEmpty else { return "출처 없음" }
        let providers = Array(Set(sources.map(\.provider))).sorted()
        let providerText = providers.prefix(3).joined(separator: " · ")
        return "\(sources.count)개 출처\(providerText.isEmpty ? "" : " · \(providerText)")"
    }

    var actionSummary: String {
        guard !actions.isEmpty else { return "다음 액션 없음" }
        return "\(actions.count)개 액션"
    }

    var artifactSummary: String {
        guard !artifacts.isEmpty else { return "artifact 없음" }
        return "\(artifacts.count)개 artifact"
    }
}
