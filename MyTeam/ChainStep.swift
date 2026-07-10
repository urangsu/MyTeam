import Foundation

enum ChainStepStatus: Codable, Sendable, Equatable {
    case pending
    case running
    case evidenceAvailable
    case planned
    case succeeded
    case failed(failureCode: String)
    case skipped(reason: String)

    var label: String {
        switch self {
        case .pending:
            return "대기"
        case .running:
            return "실행 중"
        case .evidenceAvailable:
            return "근거 확인"
        case .planned:
            return "계획"
        case .succeeded:
            return "완료"
        case .failed:
            return "실패"
        case .skipped:
            return "건너뜀"
        }
    }
}

enum ChainStatus: String, Codable, Sendable, Equatable {
    case pending
    case running
    case projected
    case succeeded
    case failed
    case blocked
}

struct ChainStep: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let key: String
    let title: String
    let connectorID: String?
    let detail: String?
    var status: ChainStepStatus
    var outputSummary: String?
    var sourceIDs: [String]
    var startedAt: Date?
    var finishedAt: Date?
    var failureDetail: String?

    init(
        id: UUID = UUID(),
        key: String,
        title: String,
        connectorID: String? = nil,
        detail: String? = nil,
        status: ChainStepStatus = .pending,
        outputSummary: String? = nil,
        sourceIDs: [String] = [],
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        failureDetail: String? = nil
    ) {
        self.id = id
        self.key = key
        self.title = title
        self.connectorID = connectorID
        self.detail = detail
        self.status = status
        self.outputSummary = outputSummary
        self.sourceIDs = sourceIDs
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.failureDetail = failureDetail
    }

    var durationText: String? {
        guard let startedAt, let finishedAt else { return nil }
        let duration = max(0, finishedAt.timeIntervalSince(startedAt))
        return String(format: "%.2fs", duration)
    }
}
