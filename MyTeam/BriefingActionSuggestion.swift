import Foundation

struct BriefingActionSuggestion: Identifiable, Equatable {
    enum Kind: String, Codable {
        case summarizeRecentFile
        case reuseRecentArtifactAsTable
        case summarizeTodayTasks
        case resumeDelegation
        case openSchedulePanel
        case approvePendingTask
        case continueRecentGoal
    }

    let id: UUID
    let kind: Kind
    let title: String
    let prompt: String?
    let systemActionID: String?
    let priority: Int
}
