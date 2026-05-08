import Foundation

struct DelegatedWorkflowPlan: Identifiable, Equatable {
    struct Step: Identifiable, Equatable {
        enum Kind: String, Codable {
            case understand
            case plan
            case askClarification
            case generateText
            case createArtifact
            case verify
            case summarize
            case requiresApproval
            case blocked
        }

        let id: UUID
        let kind: Kind
        let title: String
        let detail: String
        let expectedOutput: String?
        let requiresApproval: Bool
    }

    let id: UUID
    let contractID: UUID
    let roomID: UUID
    let title: String
    let steps: [Step]
    let expectedArtifacts: [String]
    let riskSummary: String
    let createdAt: Date
}
