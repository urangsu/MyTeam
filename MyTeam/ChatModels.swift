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
        var leaderAgentID: String? = nil
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
        var sources: [SourceReference] = []  // 웹 검색/자료 출처
    }

    struct SourceReference: Identifiable, Codable, Hashable {
        var id: UUID = UUID()
        let title: String
        let url: String
        let provider: String
        let accessedAt: Date
    }

    struct AutomationTask: Identifiable, Codable, Hashable {
        let id: UUID
        var title: String
        var prompt: String
        var nextRunAt: Date
        var repeatInterval: TimeInterval?
        var roomID: UUID?
        var isEnabled: Bool
        var createdAt: Date
        var lastRunAt: Date?

        var scheduleText: String {
            if let repeatInterval {
                if repeatInterval >= 3600 {
                    return "매 \(Int(repeatInterval / 3600))시간"
                }
                return "매 \(max(1, Int(repeatInterval / 60)))분"
            }
            return nextRunAt.formatted(date: .omitted, time: .shortened)
        }
    }

}
