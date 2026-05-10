import Combine
import Foundation

@MainActor
final class RoomRuntimeStore: ObservableObject {
    // In-memory only:
    // - active tasks
    // - active workflow step
    // - route traces
    // - last turn profile
    // - last file intake extracted text
    //
    // Future persistence candidates:
    // - recent artifact references
    // - room goal summary
    // - user-approved memory
    //
    // File 원문은 영구 저장하지 않는다.

    @Published private(set) var roomGoalContexts: [UUID: RoomGoalContext] = [:]
    @Published private(set) var lastFileIntakeResultsByRoom: [UUID: FileIntakeResult] = [:]
    @Published private(set) var activeTasksByRoom: [UUID: Task<Void, Never>] = [:]

    var isAvailable: Bool { true }
    var ownsGoalContext: Bool { true }
    var ownsFileIntake: Bool { true }
    var ownsActiveTasks: Bool { true }
    var activeTaskRoomCount: Int { activeTasksByRoom.count }

    func updateRoomGoalContext(
        roomID: UUID,
        goal: GoalInterpretation? = nil,
        activeWorkflowStep: String? = nil,
        recentArtifactID: UUID? = nil
    ) {
        var context = roomGoalContexts[roomID] ?? RoomGoalContext(
            roomID: roomID,
            currentGoal: nil,
            activeWorkflowStep: nil,
            recentArtifactIDs: [],
            updatedAt: Date()
        )

        if let goal {
            context.currentGoal = goal
        }

        if let activeWorkflowStep {
            context.activeWorkflowStep = activeWorkflowStep
        }

        if let recentArtifactID {
            context.recentArtifactIDs.insert(recentArtifactID, at: 0)
            var deduped: [UUID] = []
            for artifactID in context.recentArtifactIDs {
                if !deduped.contains(artifactID) {
                    deduped.append(artifactID)
                }
                if deduped.count == 3 { break }
            }
            context.recentArtifactIDs = deduped
        }

        context.updatedAt = Date()
        roomGoalContexts[roomID] = context
    }

    func roomGoalContext(for roomID: UUID) -> RoomGoalContext? {
        roomGoalContexts[roomID]
    }

    func recordFileIntakeResult(_ result: FileIntakeResult, roomID: UUID) {
        lastFileIntakeResultsByRoom[roomID] = result
    }

    func lastFileIntakeResult(for roomID: UUID) -> FileIntakeResult? {
        lastFileIntakeResultsByRoom[roomID]
    }

    func setActiveTask(_ task: Task<Void, Never>?, for roomID: UUID) {
        if let task {
            activeTasksByRoom[roomID] = task
        } else {
            activeTasksByRoom.removeValue(forKey: roomID)
        }
    }

    func activeTask(for roomID: UUID) -> Task<Void, Never>? {
        activeTasksByRoom[roomID]
    }

    func cancelActiveTask(for roomID: UUID) -> Task<Void, Never>? {
        let task = activeTasksByRoom.removeValue(forKey: roomID)
        task?.cancel()
        return task
    }

    func cancelAllTasks() {
        let tasks = Array(activeTasksByRoom.values)
        activeTasksByRoom.removeAll()
        tasks.forEach { $0.cancel() }
    }
}
