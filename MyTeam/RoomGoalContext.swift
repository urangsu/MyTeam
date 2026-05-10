import Foundation

struct RoomGoalContext: Equatable {
    let roomID: UUID
    var currentGoal: GoalInterpretation?
    var activeWorkflowStep: String?
    var recentArtifactIDs: [UUID]
    var updatedAt: Date
}
