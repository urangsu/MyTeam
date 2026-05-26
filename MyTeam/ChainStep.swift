import Foundation

enum ChainStepStatus: Codable, Sendable, Equatable {
    case pending
    case running
    case succeeded
    case failed(failureCode: String)
    case skipped(reason: String)

    var label: String {
        switch self {
        case .pending:
            return "pending"
        case .running:
            return "running"
        case .succeeded:
            return "succeeded"
        case .failed:
            return "failed"
        case .skipped:
            return "skipped"
        }
    }
}

enum ChainStatus: String, Codable, Sendable, Equatable {
    case pending
    case running
    case succeeded
    case failed
    case blocked
}

struct ChainStep: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let key: String
    let title: String
    let detail: String?
    var status: ChainStepStatus

    init(
        id: UUID = UUID(),
        key: String,
        title: String,
        detail: String? = nil,
        status: ChainStepStatus = .pending
    ) {
        self.id = id
        self.key = key
        self.title = title
        self.detail = detail
        self.status = status
    }
}
