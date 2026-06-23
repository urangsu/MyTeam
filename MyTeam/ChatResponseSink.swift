import Foundation

@MainActor
struct ChatResponseSink {
    static func addProgress(
        roomID: UUID,
        manager: AgentWindowManager,
        text: String
    ) -> UUID? {
        manager.addChatLog(
            roomID: roomID,
            agentID: "system",
            agentName: "업무 실행",
            text: text,
            isUser: false
        )
    }

    static func updateOrAppend(
        roomID: UUID,
        manager: AgentWindowManager,
        messageID: UUID?,
        text: String,
        agentName: String
    ) {
        if let messageID {
            manager.updateChatLogText(
                roomID: roomID,
                messageID: messageID,
                text: text
            )
        } else {
            manager.addChatLog(
                roomID: roomID,
                agentID: "system",
                agentName: agentName,
                text: text,
                isUser: false
            )
        }
    }
}
