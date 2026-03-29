import Foundation

// MARK: - Notification 이름 정의
// FloatingPanel ↔ TeamTableView 드래그 상태 통신용
extension Notification.Name {
    static let agentDragBegan = Notification.Name("agentDragBegan")
    static let agentDragEnded = Notification.Name("agentDragEnded")

    // 캐릭터 감정 표현 트리거
    // userInfo: ["agentID": String, "emote": String (AnimationState.rawValue)]
    // 예시: ["agentID": "agent_1", "emote": "joy"]
    static let characterEmote = Notification.Name("characterEmote")
}

// MARK: - 감정 표현 편의 함수
// WebSocketClient나 다른 곳에서 캐릭터 감정을 쉽게 트리거할 수 있습니다.
// 사용법:
//   CharacterEmoteHelper.trigger(agentID: "agent_1", emote: "joy")
struct CharacterEmoteHelper {
    static func trigger(agentID: String, emote: String) {
        NotificationCenter.default.post(
            name: .characterEmote,
            object: nil,
            userInfo: ["agentID": agentID, "emote": emote]
        )
    }
}
