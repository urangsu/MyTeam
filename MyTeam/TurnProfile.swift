import Foundation

struct TurnProfile: Identifiable, Equatable {
    enum Route: String, Codable {
        case localSkill
        case appLaunchPack
        case privacyTerms
        case artifactWorkflow
        case teamDiscussion
        case directChat
        case chitchat
        case disabledSkill
        case blockedHighRiskSkill
        case unknown
    }

    let id: UUID
    let roomID: UUID
    let userMessagePreview: String
    let selectedRoute: Route
    let routeReason: String
    let matchedSkillIDs: [String]
    let disabledSkillIDs: [String]
    let effectiveScopes: [String]
    let candidateTools: [String]
    let blockedTools: [String]
    let expectedOutput: String
    let requiresApproval: Bool
    let createdAt: Date
}
