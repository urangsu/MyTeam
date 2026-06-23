import Foundation

enum PendingNaturalWorkResolution: Sendable {
    case cancelled(message: String)
    case mergedText(String, shouldClearAfterPlan: Bool)
    case noPending(String)

    var routeText: String? {
        switch self {
        case .cancelled:
            return nil
        case .mergedText(let text, _), .noPending(let text):
            return text
        }
    }

    var shouldClearAfterPlan: Bool {
        if case .mergedText(_, let shouldClear) = self { return shouldClear }
        return false
    }
}

@MainActor
struct PendingNaturalWorkCoordinator {
    static func resolve(
        userMessage: String,
        roomID: UUID,
        manager: AgentWindowManager
    ) -> PendingNaturalWorkResolution {
        guard let pending = PendingNaturalWorkRequestStore.shared.pending(roomID: roomID) else {
            return .noPending(userMessage)
        }
        if PendingNaturalWorkRequestStore.isCancellation(userMessage) {
            PendingNaturalWorkRequestStore.shared.clear(roomID: roomID)
            ChatResponseSink.updateOrAppend(
                roomID: roomID,
                manager: manager,
                messageID: nil,
                text: "요청을 취소했습니다.",
                agentName: "업무 실행"
            )
            return .cancelled(message: "요청을 취소했습니다.")
        }
        return .mergedText(
            PendingNaturalWorkRequestStore.shared.mergedText(userMessage, into: pending),
            shouldClearAfterPlan: true
        )
    }

    static func storeClarification(
        _ request: NaturalClarificationRequest,
        roomID: UUID,
        manager: AgentWindowManager
    ) {
        PendingNaturalWorkRequestStore.shared.set(request, roomID: roomID)
        ChatResponseSink.updateOrAppend(
            roomID: roomID,
            manager: manager,
            messageID: nil,
            text: NaturalWorkRouter.clarificationMarkdown(for: request),
            agentName: "업무 실행"
        )
    }

    static func clear(roomID: UUID) {
        PendingNaturalWorkRequestStore.shared.clear(roomID: roomID)
    }
}
