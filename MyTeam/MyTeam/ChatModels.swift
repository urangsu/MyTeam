import Foundation

// MARK: - Chat Data Models (AgentWindowManager에서 분리)
// AgentWindowManager.ChatRoom / AgentWindowManager.ChatLog 타입 유지

extension AgentWindowManager {

    // ── 채팅방(프로젝트) 모델 ──
    struct ChatRoom: Identifiable, Codable {
        let id: UUID
        var name: String
        var messages: [ChatLog]
        var agentIDs: [String]
        let createdAt: Date
    }

    // ── 채팅 메시지 모델 ──
    struct ChatLog: Identifiable, Codable {
        let id: UUID
        let agentID: String
        let agentName: String
        let text: String
        let isUser: Bool
        let timestamp: Date
        var isSystem: Bool = false  // 드래그/이벤트 등 시스템 대사 (채팅창에 표시 안 함)
        var attachments: [ChatAttachment] = []  // 첨부파일
    }

}
