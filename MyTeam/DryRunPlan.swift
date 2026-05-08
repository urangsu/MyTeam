import Foundation

struct DryRunPlan: Identifiable, Equatable {
    enum ActionKind: String, Codable {
        case answer
        case localSkill
        case llmSkill
        case artifactCreate
        case toolExecute
        case externalWrite
        case blocked
    }

    let id: UUID
    let roomID: UUID
    let actionKind: ActionKind
    let title: String
    let steps: [String]
    let expectedArtifacts: [String]
    let requiredScopes: [String]
    let requiresApproval: Bool
    let riskSummary: String
}
