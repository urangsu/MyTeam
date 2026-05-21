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
    // Round 256A-260Z: Extended event set
    case fileReadStarted(filename: String, roomID: UUID)
    case verificationWarning(detail: String, roomID: UUID)
    case verificationFailed(detail: String, roomID: UUID)
    case approvalWaiting(taskID: String, roomID: UUID)
    case taskCompleted(skillID: String, roomID: UUID)
    case errorRecoveryStarted(roomID: UUID)
    case longIdleTriggered(roomID: UUID)

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
        case .fileReadStarted(let filename, _):
            return "fileRead_\(filename)"
        case .verificationWarning(let detail, _):
            return "verificationWarning_\(detail.prefix(20))"
        case .verificationFailed(let detail, _):
            return "verificationFailed_\(detail.prefix(20))"
        case .approvalWaiting(let taskID, _):
            return "approvalWaiting_\(taskID)"
        case .taskCompleted(let skillID, _):
            return "taskCompleted_\(skillID)"
        case .errorRecoveryStarted:
            return "errorRecovery"
        case .longIdleTriggered:
            return "longIdle"
        }
    }

    var roomID: UUID? {
        switch self {
        case .workroomOpened(let roomID),
             .workflowStarted(_, let roomID),
             .documentCreated(_, let roomID),
             .artifactReuseRequested(_, let roomID),
             .fileReadStarted(_, let roomID),
             .verificationWarning(_, let roomID),
             .verificationFailed(_, let roomID),
             .approvalWaiting(_, let roomID),
             .taskCompleted(_, let roomID),
             .errorRecoveryStarted(let roomID),
             .longIdleTriggered(let roomID):
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
            return CharacterReaction(event: event, targetState: .greeting, responseText: "워크룸에 오신 걸 환영해요!")
        case .workflowStarted(let type, _):
            return workflowStartedReaction(event: event, workflowType: type)
        case .documentCreated:
            return CharacterReaction(event: event, targetState: .joy, responseText: "문서가 만들어졌어요! 확인해보세요.")
        case .artifactReuseRequested:
            return CharacterReaction(event: event, targetState: .backToWork, responseText: "이전 결과를 다시 활용해드릴게요.")
        case .multiRoomSwitched:
            return CharacterReaction(event: event, targetState: .idle, responseText: "", cooldown: 5)
        case .fileReadStarted(let filename, _):
            let name = (filename as NSString).lastPathComponent
            return CharacterReaction(event: event, targetState: .thinking, responseText: "\(name) 읽는 중이에요.", cooldown: 10)
        case .verificationWarning:
            return CharacterReaction(event: event, targetState: .confused, responseText: "뭔가 이상한 게 있어요. 확인해볼게요.", cooldown: 15)
        case .verificationFailed:
            return CharacterReaction(event: event, targetState: .sad, responseText: "확인 중 문제가 발생했어요.", cooldown: 20)
        case .approvalWaiting:
            return CharacterReaction(event: event, targetState: .resting, responseText: "승인을 기다리고 있어요.", cooldown: 60)
        case .taskCompleted(let skillID, _):
            let name = skillID.components(separatedBy: ".").last ?? skillID
            return CharacterReaction(event: event, targetState: .backToWork, responseText: "\(name) 완료했어요!", cooldown: 20)
        case .errorRecoveryStarted:
            return CharacterReaction(event: event, targetState: .thinking, responseText: "다시 시도해볼게요.", cooldown: 15)
        case .longIdleTriggered:
            return CharacterReaction(event: event, targetState: .sleeping, responseText: "음...", cooldown: 300)
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
