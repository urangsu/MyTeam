import Foundation

// MARK: - Artifact/Verification Status Enums

enum ArtifactPersistenceStatusType: String, Equatable {
    case succeeded
    case failed
    case skipped
}

enum VerificationStatusType: String, Equatable {
    case passed
    case passedWithWarnings
    case failed
    case skipped
}

enum PlanExecutionStatusType: String, Equatable {
    case completed
    case failed
    case cancelled
    case fellBackToLegacy
}

// MARK: - RoomGoalContext

struct RoomGoalContext: Equatable {
    let roomID: UUID
    var currentGoal: GoalInterpretation?
    var activeWorkflowStep: String?
    var recentArtifactIDs: [UUID]
    var updatedAt: Date

    // Artifact / Verification tracking (for diagnostics)
    var lastArtifactPersistenceStatus: ArtifactPersistenceStatusType?
    var lastVerificationStatus: VerificationStatusType?
    var lastVerificationFailureReason: String?
    var lastPlanExecutionStatus: PlanExecutionStatusType?

    init(
        roomID: UUID,
        currentGoal: GoalInterpretation? = nil,
        activeWorkflowStep: String? = nil,
        recentArtifactIDs: [UUID] = [],
        updatedAt: Date = Date(),
        lastArtifactPersistenceStatus: ArtifactPersistenceStatusType? = nil,
        lastVerificationStatus: VerificationStatusType? = nil,
        lastVerificationFailureReason: String? = nil,
        lastPlanExecutionStatus: PlanExecutionStatusType? = nil
    ) {
        self.roomID = roomID
        self.currentGoal = currentGoal
        self.activeWorkflowStep = activeWorkflowStep
        self.recentArtifactIDs = recentArtifactIDs
        self.updatedAt = updatedAt
        self.lastArtifactPersistenceStatus = lastArtifactPersistenceStatus
        self.lastVerificationStatus = lastVerificationStatus
        self.lastVerificationFailureReason = lastVerificationFailureReason
        self.lastPlanExecutionStatus = lastPlanExecutionStatus
    }
}
