import Foundation

enum LocalSchedulerCommandKind: String, Codable, Equatable {
    case openSchedulePanel
    case showTodaySchedule
    case showPendingApprovals
    case summarizeRemainingWork
    case summarizeScheduleBasedTasks
    case showDelegatedWork
    case showSchedulePolicy
}

struct LocalSchedulerCommand: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: LocalSchedulerCommandKind
    let sourceMessage: String
    let requiresApproval: Bool

    init(
        kind: LocalSchedulerCommandKind,
        sourceMessage: String,
        requiresApproval: Bool = false
    ) {
        self.id = UUID()
        self.kind = kind
        self.sourceMessage = sourceMessage
        self.requiresApproval = requiresApproval
    }
}
