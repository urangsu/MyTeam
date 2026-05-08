import Foundation

struct TeamRuntimeState: Equatable {
    enum Kind: String {
        case idle
        case discussionStarted
        case selectingSpeaker
        case agentTurnStarted
        case agentTurnCompleted
        case discussionCompleted
        case discussionFailed
    }

    let kind: Kind
    let roomID: UUID
    let agentID: String?
    let agentName: String?
    let title: String
    let detail: String
    let timestamp: Date
    let fallbackUsed: Bool

    var isRecent: Bool {
        Date().timeIntervalSince(timestamp) <= 30
    }

    static func discussionStarted(roomID: UUID, detail: String = "팀 의견을 정리하는 중입니다.") -> TeamRuntimeState {
        TeamRuntimeState(
            kind: .discussionStarted,
            roomID: roomID,
            agentID: nil,
            agentName: nil,
            title: "팀 협업 시작",
            detail: detail,
            timestamp: Date(),
            fallbackUsed: false
        )
    }

    static func selectingSpeaker(roomID: UUID, detail: String = "다음 담당자를 고르는 중입니다.") -> TeamRuntimeState {
        TeamRuntimeState(
            kind: .selectingSpeaker,
            roomID: roomID,
            agentID: nil,
            agentName: nil,
            title: "다음 담당자 선택 중",
            detail: detail,
            timestamp: Date(),
            fallbackUsed: false
        )
    }

    static func agentTurnStarted(
        roomID: UUID,
        agentID: String,
        agentName: String,
        detail: String,
        fallbackUsed: Bool = false
    ) -> TeamRuntimeState {
        TeamRuntimeState(
            kind: .agentTurnStarted,
            roomID: roomID,
            agentID: agentID,
            agentName: agentName,
            title: "\(agentName) 검토 중",
            detail: detail,
            timestamp: Date(),
            fallbackUsed: fallbackUsed
        )
    }

    static func agentTurnCompleted(
        roomID: UUID,
        agentID: String,
        agentName: String,
        detail: String = "응답 완료"
    ) -> TeamRuntimeState {
        TeamRuntimeState(
            kind: .agentTurnCompleted,
            roomID: roomID,
            agentID: agentID,
            agentName: agentName,
            title: "\(agentName) 응답 완료",
            detail: detail,
            timestamp: Date(),
            fallbackUsed: false
        )
    }

    static func discussionCompleted(roomID: UUID, detail: String = "팀 의견 정리 완료") -> TeamRuntimeState {
        TeamRuntimeState(
            kind: .discussionCompleted,
            roomID: roomID,
            agentID: nil,
            agentName: nil,
            title: "팀 협업 완료",
            detail: detail,
            timestamp: Date(),
            fallbackUsed: false
        )
    }

    static func discussionFailed(roomID: UUID, detail: String) -> TeamRuntimeState {
        TeamRuntimeState(
            kind: .discussionFailed,
            roomID: roomID,
            agentID: nil,
            agentName: nil,
            title: "확인 필요",
            detail: detail,
            timestamp: Date(),
            fallbackUsed: false
        )
    }
}
