import Foundation

enum ToolExecutionLogState: String, Sendable, Equatable {
    case running
    case succeeded
    case failed
    case blocked
}

struct ToolExecutionLogEntry: Identifiable, Sendable, Equatable {
    let id: UUID
    let toolID: String
    let displayName: String
    let startedAt: Date
    let finishedAt: Date?
    let state: ToolExecutionLogState
    let provider: ExternalProvider?
    let failureMessage: String?
}
