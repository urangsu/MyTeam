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
        case .prefillInput(let template):
            manager.addChatLog(
                roomID: roomID,
                agentID: "assistant",
                agentName: "MyTeam",
                text: "입력창에 아래 형식을 넣고, 대상 내용이나 파일을 지정한 뒤 보내주세요.\n\n\(template)",
                isUser: false
            )
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
