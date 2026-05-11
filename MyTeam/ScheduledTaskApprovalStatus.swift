import Foundation

enum ScheduledTaskApprovalStatus: String, Codable, Equatable {
    case none
    case scheduledRequiresApproval
    case awaitingApproval
    case approved
    case skipped
    case expired
}

enum ScheduledTaskApprovalResolver {
    static func status(
        for task: AgentWindowManager.AutomationTask,
        roomID: UUID,
        manager: AgentWindowManager
    ) -> ScheduledTaskApprovalStatus {
        guard task.roomID == nil || task.roomID == roomID else {
            return .none
        }

        if manager.pendingApprovalTaskIDs.contains(task.id) {
            return .awaitingApproval
        }

        if task.requiresApproval {
            return .scheduledRequiresApproval
        }

        return .none
    }

    static func hasAwaitingApproval(
        roomID: UUID,
        manager: AgentWindowManager
    ) -> Bool {
        manager.automationTasks.contains { task in
            guard task.roomID == nil || task.roomID == roomID else { return false }
            return manager.pendingApprovalTaskIDs.contains(task.id)
        }
    }

    static func hasScheduledRequiresApproval(
        roomID: UUID,
        manager: AgentWindowManager
    ) -> Bool {
        manager.automationTasks.contains { task in
            guard task.roomID == nil || task.roomID == roomID else { return false }
            return task.requiresApproval
        }
    }
}
