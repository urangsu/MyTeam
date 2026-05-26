import Foundation

enum ActionRuntime {
    @MainActor
    static func execute(
        _ action: ActionSuggestion,
        roomID: UUID,
        manager: AgentWindowManager,
        orchestrator: WorkflowOrchestrator? = nil
    ) async -> ActionExecutionResult {
        let orchestrator = orchestrator ?? .shared
        guard let handlerID = action.handlerID else {
            return .queued("핸들러가 연결되지 않은 액션입니다.", prompt: action.title)
        }

        if ApprovalBinder.requiresApproval(for: handlerID) || action.requiresApproval {
            return .approvalNeeded(
                "이 액션은 승인 후 진행됩니다.",
                prompt: action.title,
                handlerID: handlerID
            )
        }

        switch handlerID {
        case .replyDraft:
            await orchestrator.dispatch(
                userMessage: action.preview,
                roomID: roomID,
                manager: manager
            )
            return .completed("답장 초안 라우트를 실행했습니다.", handlerID: handlerID)

        case .todoCreate:
            await orchestrator.dispatch(
                userMessage: action.preview,
                roomID: roomID,
                manager: manager
            )
            return .completed("할 일 저장 요청을 실행했습니다.", handlerID: handlerID)

        case .saveMemo:
            await orchestrator.dispatch(
                userMessage: action.preview,
                roomID: roomID,
                manager: manager
            )
            return .completed("메모 저장 라우트를 실행했습니다.", handlerID: handlerID)

        case .createDocument:
            await orchestrator.dispatch(
                userMessage: action.preview,
                roomID: roomID,
                manager: manager
            )
            return .completed("문서 생성 라우트를 실행했습니다.", handlerID: handlerID)

        case .summarizeArtifact:
            await orchestrator.dispatch(
                userMessage: action.preview,
                roomID: roomID,
                manager: manager
            )
            return .completed("문서 요약 라우트를 실행했습니다.", handlerID: handlerID)

        case .calendarDraft:
            return .approvalNeeded(
                "캘린더 초안은 승인 후 진행됩니다.",
                prompt: action.preview,
                handlerID: handlerID
            )

        case .openMap:
            return .queued("지도 열기 액션을 준비했습니다.", prompt: action.preview, handlerID: handlerID)

        case .openBooking:
            return .approvalNeeded(
                "예약/예매는 승인 후 진행됩니다.",
                prompt: action.preview,
                handlerID: handlerID
            )
        }
    }
}
