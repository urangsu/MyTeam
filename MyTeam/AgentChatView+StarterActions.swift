import SwiftUI

// MARK: - AgentChatView StarterAction Extension
// StarterAction.swift, StarterActionStripView.swift 이후에 컴파일됩니다.
// AgentChatView.swift와의 순환 컴파일 순서 문제를 피하기 위해 분리된 extension으로 구현합니다.

extension AgentChatView {

    // MARK: - Starter Actions 뷰 (빈 채팅 상태에서 표시)
    @ViewBuilder
    var starterActionsStripView: some View {
        StarterActionStripView(
            actions: StarterActionProvider.actions(),
            onActionTap: { action in
                dispatchStarterAction(action)
            }
        )
    }

    // MARK: - 스타터 액션 디스패치
    // WorkflowOrchestrator를 통해 라우팅하여 universalDocument, artifactWorkflow 등으로 분기
    func dispatchStarterAction(_ action: StarterAction) {
        // roomID 확보 (없으면 생성)
        guard let roomID = _ensureRoomID() else { return }

        switch action.actionType {
        case .userMessage(let prompt):
            // ── WorkflowOrchestrator를 통해 라우팅 ──
            // GoalInterpreter → CapabilityAwareRouter → RouteResolver → 최적 경로
            // "회의록 양식 만들어줘" → universalDocument / meetingMinutes
            // "PPT 만들어줘" → artifactWorkflow
            // 기타 → directChat
            Task {
                await WorkflowOrchestrator.shared.dispatch(
                    userMessage: prompt,
                    roomID: roomID,
                    manager: manager
                )
            }
        case .fileIntakeOpen:
            _openFileIntake()
        }
    }
}
