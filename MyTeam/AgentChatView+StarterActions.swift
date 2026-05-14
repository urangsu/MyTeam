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
    func dispatchStarterAction(_ action: StarterAction) {
        // roomID 확보 (없으면 생성)
        guard _ensureRoomID() != nil else { return }

        switch action.actionType {
        case .userMessage(let prompt):
            _sendStarterPrompt(prompt)
        case .fileIntakeOpen:
            _openFileIntake()
        }
    }
}
