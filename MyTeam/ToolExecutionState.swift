import Foundation

struct MyTeamToolInput: Sendable, Equatable {
    var query: String?
    var daysBack: Int?
    var displayCount: Int?
    var nx: Int?
    var ny: Int?
    var providerHint: ExternalProvider?

    nonisolated init(
        query: String? = nil,
        daysBack: Int? = nil,
        displayCount: Int? = nil,
        nx: Int? = nil,
        ny: Int? = nil,
        providerHint: ExternalProvider? = nil
    ) {
        self.query = query
        self.daysBack = daysBack
        self.displayCount = displayCount
        self.nx = nx
        self.ny = ny
        self.providerHint = providerHint
    }
}

enum ToolExecutionState: Sendable, Equatable {
    case idle
    case checkingReadiness
    case needsConnection(ExternalProvider)
    case needsValidation(ExternalProvider)
    case needsApproval(String)
    case running
    case succeeded(MyTeamToolResult)
    case failed(MyTeamToolFailure)
    case unavailable(String)
}

struct MyTeamToolResult: Sendable, Equatable {
    let title: String
    let summary: String
    let sourceLabel: String?
    let body: String?
    let items: [MyTeamToolResultItem]
    let nextActions: [MyTeamNextAction]
}

struct MyTeamToolResultItem: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    let metadata: String?
    let sourceURL: URL?
}

struct MyTeamToolFailure: Sendable, Equatable {
    let title: String
    let message: String
    let recoveryActions: [MyTeamNextAction]
}

struct MyTeamNextAction: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let role: ActionRole
}

enum ActionRole: String, Sendable, Equatable {
    case normal
    case approval
    case destructive
}

extension ToolExecutionState {
    nonisolated var displayLabel: String {
        switch self {
        case .idle: return "준비"
        case .checkingReadiness: return "확인 중"
        case .needsConnection: return "연결 필요"
        case .needsValidation: return "검증 필요"
        case .needsApproval: return "승인 필요"
        case .running: return "실행 중"
        case .succeeded: return "완료"
        case .failed: return "실패"
        case .unavailable: return "준비 중"
        }
    }

    nonisolated var isRunnable: Bool {
        switch self {
        case .idle:
            return true
        default:
            return false
        }
    }
}
