import Foundation

struct WorkStep: Identifiable, Codable, Equatable {
    enum StepKind: String, Codable {
        case llmGenerate
        case verifyMarkdown
        case persistArtifact
        case report
        case toolExecute
        case agentDelegate
        case userCheckpoint
    }

    let id: UUID
    let kind: StepKind
    let title: String
    let inputKeys: [String]
    let outputKey: String?
    let prompt: String?
    let verificationLevel: VerificationLevel
    let maxRetries: Int
}
