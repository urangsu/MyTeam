import Foundation

@MainActor
enum BriefingActionIntegrityPolicy {
    static func isExecutable(
        _ action: BriefingActionSuggestion,
        roomID: UUID,
        manager: AgentWindowManager
    ) -> Bool {
        switch action.kind {
        case .summarizeRecentFile:
            guard let result = manager.lastFileIntakeResult(for: roomID) else { return false }
            return result.status == .ready

        case .reuseRecentArtifactAsTable:
            return RecentArtifactContentResolver.canResolveLatestMarkdownArtifact(
                roomID: roomID,
                manager: manager
            )

        case .summarizeTodayTasks, .openSchedulePanel:
            return hasScheduleTasks(roomID: roomID, manager: manager)

        case .resumeDelegation:
            return hasPendingDelegation(roomID: roomID, manager: manager)

        case .showPendingApprovals:
            return hasPendingApprovals(roomID: roomID, manager: manager)

        case .continueRecentGoal:
            return manager.roomGoalContext(for: roomID)?.currentGoal != nil
        }
    }

    private static func hasScheduleTasks(roomID: UUID, manager: AgentWindowManager) -> Bool {
        let now = Date()
        let calendar = Calendar.current
        return manager.automationTasks.contains { task in
            guard task.isEnabled else { return false }
            guard task.roomID == nil || task.roomID == roomID else { return false }
            return calendar.isDate(task.nextRunAt, inSameDayAs: now)
        }
    }

    private static func hasPendingApprovals(roomID: UUID, manager: AgentWindowManager) -> Bool {
        manager.automationTasks.contains { task in
            guard task.roomID == nil || task.roomID == roomID else { return false }
            return task.requiresApproval || manager.pendingApprovalTaskIDs.contains(task.id)
        }
    }

    private static func hasPendingDelegation(roomID: UUID, manager: AgentWindowManager) -> Bool {
        if let state = manager.delegationModeState(for: roomID), state.status == .awaitingApproval {
            return true
        }
        return manager.pendingDelegatedExecutionRequest(for: roomID) != nil
    }
}
