import Foundation

@MainActor
enum BriefingActionDispatcher {
    static func dispatch(
        _ action: BriefingActionSuggestion,
        roomID: UUID,
        manager: AgentWindowManager,
        orchestrator: WorkflowOrchestrator
    ) async {
        switch action.executionMode {
        case .systemAction:
            await handleSystemAction(action, roomID: roomID, manager: manager, orchestrator: orchestrator)
        case .promptRoute:
            await handlePromptAction(action, roomID: roomID, manager: manager, orchestrator: orchestrator)
        }
    }

    private static func handleSystemAction(
        _ action: BriefingActionSuggestion,
        roomID: UUID,
        manager: AgentWindowManager,
        orchestrator: WorkflowOrchestrator
    ) async {
        switch action.systemActionID {
        case "openSchedulePanel":
            manager.isSchedulePanelPresented = true
            return

        case "showPendingApprovals":
            manager.isSchedulePanelPresented = true
            if !hasPendingApprovalTask(roomID: roomID, manager: manager) {
                let fallback = action.prompt?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? "승인 대기 보여줘"
                await handlePromptFallback(fallback, roomID: roomID, manager: manager, orchestrator: orchestrator)
            }
            return

        default:
            if let prompt = action.prompt?.trimmingCharacters(in: .whitespacesAndNewlines),
               !prompt.isEmpty {
                await handlePromptFallback(prompt, roomID: roomID, manager: manager, orchestrator: orchestrator)
            }
        }
    }

    private static func handlePromptAction(
        _ action: BriefingActionSuggestion,
        roomID: UUID,
        manager: AgentWindowManager,
        orchestrator: WorkflowOrchestrator
    ) async {
        guard let prompt = action.prompt?.trimmingCharacters(in: .whitespacesAndNewlines),
              !prompt.isEmpty else {
            return
        }
        await handlePromptFallback(prompt, roomID: roomID, manager: manager, orchestrator: orchestrator)
    }

    private static func handlePromptFallback(
        _ prompt: String,
        roomID: UUID,
        manager: AgentWindowManager,
        orchestrator: WorkflowOrchestrator
    ) async {
        manager.addChatLog(
            roomID: roomID,
            agentID: "user",
            agentName: "나",
            text: prompt,
            isUser: true
        )

        await orchestrator.dispatch(
            userMessage: prompt,
            roomID: roomID,
            manager: manager
        )
    }

    private static func hasPendingApprovalTask(roomID: UUID, manager: AgentWindowManager) -> Bool {
        manager.automationTasks.contains { task in
            guard task.roomID == nil || task.roomID == roomID else { return false }
            return task.requiresApproval || manager.pendingApprovalTaskIDs.contains(task.id)
        }
    }
}
