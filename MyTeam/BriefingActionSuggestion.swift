import Foundation

struct BriefingActionSuggestion: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case summarizeRecentFile
        case reuseRecentArtifactAsTable
        case summarizeTodayTasks
        case resumeDelegation
        case openSchedulePanel
        case showPendingApprovals
        case continueRecentGoal
    }

    enum ExecutionMode: String, Codable {
        case promptRoute
        case systemAction
    }

    let id: UUID
    let kind: Kind
    let title: String
    let subtitle: String?
    let prompt: String?
    let systemActionID: String?
    let executionMode: ExecutionMode
    let priority: Int
    let sourceBinding: RecentArtifactSourceBinding?

    init(
        id: UUID,
        kind: Kind,
        title: String,
        subtitle: String?,
        prompt: String?,
        systemActionID: String?,
        executionMode: ExecutionMode,
        priority: Int,
        sourceBinding: RecentArtifactSourceBinding? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.prompt = prompt
        self.systemActionID = systemActionID
        self.executionMode = executionMode
        self.priority = priority
        self.sourceBinding = sourceBinding
    }
}
