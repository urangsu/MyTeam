import Foundation

enum MyTeamPlan: String, Codable, CaseIterable {
    case free
    case pro

    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .pro:
            return "Pro"
        }
    }
}

struct PlanLimits: Codable, Hashable {
    let includedAIMessagesPerDay: Int
    let maxActiveAgents: Int
    let maxArtifactsPerDay: Int
    let allowTeamDiscussion: Bool
    let allowCharacterCustomization: Bool
    let allowAllBuiltInSkills: Bool
}

enum MonetizationPlanCatalog {
    static let free = PlanLimits(
        includedAIMessagesPerDay: 20,
        maxActiveAgents: 3,
        maxArtifactsPerDay: 3,
        allowTeamDiscussion: false,
        allowCharacterCustomization: false,
        allowAllBuiltInSkills: false
    )

    static let pro = PlanLimits(
        includedAIMessagesPerDay: 100,
        maxActiveAgents: 11,
        maxArtifactsPerDay: 50,
        allowTeamDiscussion: true,
        allowCharacterCustomization: true,
        allowAllBuiltInSkills: true
    )

    static func limits(for plan: MyTeamPlan) -> PlanLimits {
        switch plan {
        case .free:
            return free
        case .pro:
            return pro
        }
    }
}
