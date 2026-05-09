import Foundation

struct RouterBurnInCase: Identifiable, Equatable {
    enum ExpectedRoute: String, Codable {
        case localSkill
        case appLaunchPack
        case privacyTerms
        case artifactWorkflow
        case teamDiscussion
        case directChat
        case disabledSkill
        case blockedHighRiskSkill
        case delegationAwaitingApproval
        case delegationApproval
        case delegationCancel
        case unknown
    }

    let id: String
    let message: String
    let expectedRoute: ExpectedRoute
    let expectedSkillID: String?
    let expectedRouteHint: String?
    let shouldRequireApproval: Bool
    let notes: String
}

struct RouterBurnInResult: Identifiable, Equatable {
    let id: String
    let passed: Bool
    let expected: String
    let actual: String
    let notes: String
}

struct RouterBurnInSummary: Equatable {
    let total: Int
    let passed: Int
    let failed: Int
    let failures: [RouterBurnInResult]
}
