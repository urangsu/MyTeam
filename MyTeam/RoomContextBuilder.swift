import Foundation

// MARK: - RoomContextBuilder
// Round 270D: Room-scoped context injection for LLM calls.
//
// WorkflowOrchestrator LLM 호출 시 chatHistory: [] 대신
// 현재 워크룸의 최근 메시지를 context로 주입한다.
//
// Policy:
// - 최근 N개 non-system 메시지만 사용 (기본 10개)
// - cross-room contamination 없음 — roomID로 격리
// - manager.rooms는 @MainActor에서만 접근
// - build()는 @MainActor에서 호출; 결과(RoomContext)는 Sendable

// MARK: - RoomContext

struct RoomContext: Sendable {
    let roomID: UUID
    let roomPurpose: String
    let recentMessages: [AgentWindowManager.ChatLog]
    let recentArtifactSummaries: [String]

    /// LLM system prompt에 삽입할 수 있는 형태로 직렬화
    var systemPromptContext: String {
        var parts: [String] = []
        parts.append("현재 워크룸: \(roomPurpose)")
        if !recentMessages.isEmpty {
            let history = recentMessages.suffix(10).map {
                "\($0.agentName): \($0.text)"
            }.joined(separator: "\n")
            parts.append("최근 대화:\n\(history)")
        }
        if !recentArtifactSummaries.isEmpty {
            parts.append("최근 아티팩트: \(recentArtifactSummaries.joined(separator: ", "))")
        }
        return parts.joined(separator: "\n\n")
    }

    /// chatHistory에 주입할 메시지 목록 (system 메시지 제외)
    var contextualChatHistory: [AgentWindowManager.ChatLog] {
        recentMessages.filter { !$0.isSystem }
    }
}

// MARK: - RoomContextBuilder

enum RoomContextBuilder {

    /// 워크룸 컨텍스트를 빌드한다.
    /// - Parameters:
    ///   - manager: AgentWindowManager (rooms 접근용)
    ///   - roomID: 대상 워크룸 UUID
    ///   - maxMessages: 최대 포함 메시지 수 (기본 10)
    /// - Returns: RoomContext (Sendable, actor 경계 안전)
    @MainActor
    static func build(
        manager: AgentWindowManager,
        roomID: UUID,
        maxMessages: Int = 10
    ) -> RoomContext {
        guard let room = manager.rooms.first(where: { $0.id == roomID }) else {
            return RoomContext(
                roomID: roomID,
                roomPurpose: "알 수 없는 워크룸",
                recentMessages: [],
                recentArtifactSummaries: []
            )
        }
        let recentMessages = Array(room.messages.suffix(maxMessages))
        return RoomContext(
            roomID: roomID,
            roomPurpose: room.name,
            recentMessages: recentMessages,
            recentArtifactSummaries: []
        )
    }
}
