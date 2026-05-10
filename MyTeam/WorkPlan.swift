import Foundation

struct WorkPlan: Identifiable, Codable, Equatable {
    enum WorkflowKind: String, Codable {
        case universalDocument
        case appLaunch
        case privacyTerms
        case fileIntake
        case teamPipeline
    }

    let id: UUID
    let roomID: UUID
    let goal: String
    let workflowKind: WorkflowKind
    let steps: [WorkStep]
    let recoveryAction: RecoveryAction
    let createdAt: Date
}
