import Foundation

struct RouterBurnInCase: Identifiable, Equatable {
    enum ExpectedRoute: String, Codable {
        case localSkill
        case appLaunchPack
        case privacyTerms
        case universalDocument
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
    let expectedGoalType: String?
    let shouldRequireApproval: Bool
    let notes: String

    init(
        id: String,
        message: String,
        expectedRoute: ExpectedRoute,
        expectedSkillID: String?,
        expectedRouteHint: String?,
        expectedGoalType: String? = nil,
        shouldRequireApproval: Bool,
        notes: String
    ) {
        self.id = id
        self.message = message
        self.expectedRoute = expectedRoute
        self.expectedSkillID = expectedSkillID
        self.expectedRouteHint = expectedRouteHint
        self.expectedGoalType = expectedGoalType
        self.shouldRequireApproval = shouldRequireApproval
        self.notes = notes
    }
}

struct RouterBurnInResult: Identifiable, Equatable {
    let id: String
    let passed: Bool
    let expected: String
    let actual: String
    let expectedGoalType: String?
    let actualGoalType: String?
    let goalPassed: Bool?
    let notes: String
}

struct RouterBurnInSummary: Equatable {
    let total: Int
    let passed: Int
    let failed: Int
    let failures: [RouterBurnInResult]
    let goalChecked: Int
    let goalPassed: Int
    let goalFailed: Int
}
