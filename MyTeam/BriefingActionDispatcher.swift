import Foundation

@MainActor
enum BriefingActionDispatcher {
    static func dispatch(
        _ action: BriefingActionSuggestion,
        roomID: UUID,
        manager: AgentWindowManager,
        orchestrator: WorkflowOrchestrator
    ) async {
        if let sourceBinding = action.sourceBinding {
            if let failureCode = await bindingFailureCode(
                sourceBinding: sourceBinding,
                roomID: roomID,
                manager: manager
            ) {
                AppLog.warning("[BriefingActionDispatcher] \(failureCode)")
                manager.addChatLog(
                    roomID: roomID,
                    agentID: "system",
                    agentName: "스킬",
                    text: "최근 문서 상태가 바뀌어 이 액션을 실행하지 않았습니다. 오늘 브리핑을 다시 열어 최신 액션으로 진행해 주세요.",
                    isUser: false,
                    isSystem: true
                )
                return
            }
        } else if action.kind == .reuseRecentArtifactAsTable {
            AppLog.warning("[BriefingActionDispatcher] missing_action_source_binding")
            manager.addChatLog(
                roomID: roomID,
                agentID: "system",
                agentName: "스킬",
                text: "최근 문서 상태가 바뀌어 이 액션을 실행하지 않았습니다. 오늘 브리핑을 다시 열어 최신 액션으로 진행해 주세요.",
                isUser: false,
                isSystem: true
            )
            return
        }

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
        ScheduledTaskApprovalResolver.hasAwaitingApproval(roomID: roomID, manager: manager)
    }

    private static func bindingFailureCode(
        sourceBinding: RecentArtifactSourceBinding,
        roomID: UUID,
        manager: AgentWindowManager
    ) async -> String? {
        guard sourceBinding.roomID == roomID else {
            return "wrong_room_action_binding"
        }
        guard let currentBinding = await RecentArtifactContentResolver.currentBinding(roomID: roomID, manager: manager) else {
            return "stale_action_binding"
        }
        guard sourceBinding.artifactID == currentBinding.artifactID else {
            return "stale_action_binding"
        }
        guard sourceBinding.filename == currentBinding.filename else {
            return "stale_action_binding"
        }
        guard sourceBinding.contentHash == currentBinding.contentHash else {
            return "stale_action_binding"
        }
        guard sourceBinding.fileSizeBytes == currentBinding.fileSizeBytes else {
            return "stale_action_binding"
        }
        guard sourceBinding.modifiedAt == currentBinding.modifiedAt else {
            return "stale_action_binding"
        }
        guard sourceBinding.createdAt == currentBinding.createdAt else {
            return "stale_action_binding"
        }
        return nil
    }
}
