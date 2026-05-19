import Foundation

struct RouterBurnInCase: Identifiable, Equatable {
    enum ExpectedRoute: String, Codable {
        case localSkill
        case appLaunchPack
        case privacyTerms
        case localSchedulerCommand
        case localSchedulerDocumentBridge
        case dailyBriefing
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
    let expectedRecentArtifactReference: Bool?
    let shouldRequireApproval: Bool
    let expectedMemoryWriteBlocked: Bool?
    let expectedVerboseDiagnosticsVisible: Bool?
    let expectedModelOverrideAllowed: Bool?
    let expectedArtifactPathNormalized: Bool?
    let expectedArtifactPathInvalidExternal: Bool?
    let expectedArtifactPathInvalidRelative: Bool?
    let expectedArtifactMissingFile: Bool?
    let expectedArtifactHashMismatch: Bool?
    let expectedActionLogCompactionAvailable: Bool?
    let expectedCleanupDryRunPolicy: Bool?
    let expectedMemoryScope: String?    // Round 244A: "procedural" | "userProfile" | "room" | "blocked" | nil
    let notes: String

    init(
        id: String,
        message: String,
        expectedRoute: ExpectedRoute,
        expectedSkillID: String?,
        expectedRouteHint: String?,
        expectedGoalType: String? = nil,
        expectedRecentArtifactReference: Bool? = nil,
        shouldRequireApproval: Bool,
        expectedMemoryWriteBlocked: Bool? = nil,
        expectedVerboseDiagnosticsVisible: Bool? = nil,
        expectedModelOverrideAllowed: Bool? = nil,
        expectedArtifactPathNormalized: Bool? = nil,
        expectedArtifactPathInvalidExternal: Bool? = nil,
        expectedArtifactPathInvalidRelative: Bool? = nil,
        expectedArtifactMissingFile: Bool? = nil,
        expectedArtifactHashMismatch: Bool? = nil,
        expectedActionLogCompactionAvailable: Bool? = nil,
        expectedCleanupDryRunPolicy: Bool? = nil,
        expectedMemoryScope: String? = nil,
        notes: String
    ) {
        self.id = id
        self.message = message
        self.expectedRoute = expectedRoute
        self.expectedSkillID = expectedSkillID
        self.expectedRouteHint = expectedRouteHint
        self.expectedGoalType = expectedGoalType
        self.expectedRecentArtifactReference = expectedRecentArtifactReference
        self.shouldRequireApproval = shouldRequireApproval
        self.expectedMemoryWriteBlocked = expectedMemoryWriteBlocked
        self.expectedVerboseDiagnosticsVisible = expectedVerboseDiagnosticsVisible
        self.expectedModelOverrideAllowed = expectedModelOverrideAllowed
        self.expectedArtifactPathNormalized = expectedArtifactPathNormalized
        self.expectedArtifactPathInvalidExternal = expectedArtifactPathInvalidExternal
        self.expectedArtifactPathInvalidRelative = expectedArtifactPathInvalidRelative
        self.expectedArtifactMissingFile = expectedArtifactMissingFile
        self.expectedArtifactHashMismatch = expectedArtifactHashMismatch
        self.expectedActionLogCompactionAvailable = expectedActionLogCompactionAvailable
        self.expectedCleanupDryRunPolicy = expectedCleanupDryRunPolicy
        self.expectedMemoryScope = expectedMemoryScope
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
    let expectedRecentArtifactReference: Bool?
    let actualRecentArtifactReference: Bool?
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
