import Foundation

// MARK: - WorkroomCharacterEvent
// Workroom에서 발생하는 이벤트를 character reaction으로 매핑하기 위한 event type.
// AnimationState는 CharacterSpriteScene.swift에 정의된 기존 enum을 사용한다.

enum WorkroomCharacterEvent: Equatable, Identifiable {
    case workroomOpened(roomID: UUID)
    case workflowStarted(workflowType: String, roomID: UUID)
    case documentCreated(documentType: String, roomID: UUID)
    case artifactReuseRequested(artifactID: String, roomID: UUID)
    case multiRoomSwitched(fromRoomID: UUID, toRoomID: UUID)

    var id: String {
        switch self {
        case .workroomOpened(let roomID):
            return "workroomOpened_\(roomID)"
        case .workflowStarted(let type, _):
            return "workflowStarted_\(type)"
        case .documentCreated(let type, _):
            return "documentCreated_\(type)"
        case .artifactReuseRequested(let id, _):
            return "artifactReuse_\(id)"
        case .multiRoomSwitched:
            return "multiRoomSwitched"
        }
    }

    var roomID: UUID? {
        switch self {
        case .workroomOpened(let roomID),
             .workflowStarted(_, let roomID),
             .documentCreated(_, let roomID),
             .artifactReuseRequested(_, let roomID):
            return roomID
        case .multiRoomSwitched:
            return nil
        }
    }
}

// MARK: - CharacterReaction

struct CharacterReaction: Identifiable {
    let id: String          // event.id 기반 결정론적 ID
    let event: WorkroomCharacterEvent
    let targetAnimationState: AnimationState
    let responseText: String
    let cooldownSeconds: Double

    init(event: WorkroomCharacterEvent, targetState: AnimationState, responseText: String, cooldown: Double = 30) {
        self.id = event.id
        self.event = event
        self.targetAnimationState = targetState
        self.responseText = responseText
        self.cooldownSeconds = cooldown
    }
}

// MARK: - CharacterReactionMapping
// Workroom event → AnimationState 매핑.
// AnimationState 케이스는 CharacterSpriteScene.swift의 실제 enum만 사용.
// 없는 케이스는 가장 가까운 기존 케이스로 fallback.

enum CharacterReactionMapping {

    static func reactionFor(_ event: WorkroomCharacterEvent) -> CharacterReaction? {
        switch event {
        case .workroomOpened:
            // 앱 오픈 → 인사
            return CharacterReaction(event: event, targetState: .greeting, responseText: "워크룸에 오신 걸 환영해요!")
        case .workflowStarted(let type, _):
            return workflowStartedReaction(event: event, workflowType: type)
        case .documentCreated:
            // 문서 완성 → 기쁨
            return CharacterReaction(event: event, targetState: .joy, responseText: "문서가 만들어졌어요! 확인해보세요.")
        case .artifactReuseRequested:
            // 이전 결과 재사용 → 업무 복귀
            return CharacterReaction(event: event, targetState: .backToWork, responseText: "이전 결과를 다시 활용해드릴게요.")
        case .multiRoomSwitched:
            // 방 전환 → 아이들 (쿨다운 짧게)
            return CharacterReaction(event: event, targetState: .idle, responseText: "", cooldown: 5)
        }
    }

    private static func workflowStartedReaction(event: WorkroomCharacterEvent, workflowType: String) -> CharacterReaction? {
        let state: AnimationState
        let text: String

        switch workflowType.lowercased() {
        case "universaldocument":
            state = .typing      // 문서 작성 중
            text = "문서를 정리해드릴게요. 잠깐만 기다려주세요!"
        case "applaunchpack":
            state = .typing
            text = "앱 출시 준비를 도와드리겠습니다."
        case "privacyterms":
            state = .typing
            text = "개인정보처리방침을 작성해드릴게요."
        default:
            state = .thinking    // 폴백 → idle fallback
            text = "작업을 시작할게요."
        }

        return CharacterReaction(event: event, targetState: state, responseText: text)
    }
}
