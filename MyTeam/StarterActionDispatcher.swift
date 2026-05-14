import Foundation

@MainActor
enum StarterActionDispatcher {
    static func dispatch(
        _ action: StarterAction,
        roomID: UUID,
        manager: AgentWindowManager,
        orchestrator: WorkflowOrchestrator,
        onFileIntakeRequested: (() -> Void)? = nil
    ) async {
        switch action.actionType {
        case .userMessage(let prompt):
            await dispatchPrompt(prompt, roomID: roomID, manager: manager, orchestrator: orchestrator)
        case .fileIntakeOpen:
            onFileIntakeRequested?()
        }
    }

    private static func dispatchPrompt(
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
}
