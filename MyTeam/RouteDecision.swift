import Foundation

struct RouteDecision: Equatable {
    enum Kind: String, Codable {
        case blocked
        case disabledSkill
        case localSkill
        case dailyBriefing
        case appLaunch
        case privacyTerms
        case universalDocument
        case artifactWorkflow
        case directChat
        case teamDiscussion
        case fallback
    }

    let kind: Kind
    let reason: String
    let skillID: String?
    let requiresApproval: Bool
    let expectedOutput: String
}
