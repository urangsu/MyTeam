import Foundation

// MARK: - CharacterReactionDelegate
// SpriteAgentView / AgentSeatView 등이 구현하는 character reaction 렌더링 프로토콜.
// AnimationState는 CharacterSpriteScene.swift의 기존 enum을 재사용한다.

protocol CharacterReactionDelegate: AnyObject {
    func applyCharacterReaction(
        animationState: AnimationState,
        responseText: String,
        duration: Double
    ) async
}

// MARK: - CharacterReactionDiagnostics

struct CharacterReactionDiagnostics: Equatable {
    let engineAvailable: Bool
    let delegateRegistered: Bool
    let activeCooldowns: [String: String]

    var summary: String {
        "engine=\(engineAvailable) delegate=\(delegateRegistered) cooldowns=\(activeCooldowns.count)"
    }
}

// MARK: - CharacterReactionEventSink
// Workroom workflow → CharacterReactionEngine 브리지.
// 핵심 연결: event 수신 → AgentWindowManager.agentEmotions[agentID] 업데이트
// → AgentSeatView → SpriteAgentView가 새 AnimationState를 렌더링한다.

@MainActor
final class CharacterReactionEventSink {
    static let shared = CharacterReactionEventSink()

    private weak var delegate: CharacterReactionDelegate?

    private init() {
        setupWorkflowCompletedObserver()
    }

    // MARK: - WorkflowCompleted Observer
    // WorkflowEngine이 artifact를 생성 완료할 때 .joy 반응을 트리거한다.
    // WorkflowEngine / ArtifactStore 구조 변경 없이 Notification으로 연결.

    private func setupWorkflowCompletedObserver() {
        NotificationCenter.default.addObserver(
            forName: .workflowCompleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            // artifactCount > 0인 경우에만 documentCreated 반응
            let artifacts = notification.userInfo?["artifacts"] as? [Any] ?? []
            guard !artifacts.isEmpty else { return }

            // roomID: workflowCompleted에는 workspaceURL만 있어 currentRoomID로 fallback
            let roomID = AgentWindowManager.shared.currentRoomID ?? UUID()
            self.notifyDocumentCreated(documentType: "workflowArtifact", roomID: roomID)
        }
    }

    // MARK: - Delegate Registration

    func registerDelegate(_ delegate: CharacterReactionDelegate?) {
        self.delegate = delegate
        AppLog.debug("CharacterReactionEventSink: delegate registered=\(delegate != nil)")
    }

    // MARK: - Event Posting (Workroom integration points)

    /// WorkroomHomeView 표시 시 호출
    func notifyWorkroomOpened(roomID: UUID) {
        postEvent(.workroomOpened(roomID: roomID))
    }

    /// handleWorkroomAction(.createDocument) → documentGenerationStarted
    func notifyDocumentGenerationStarted(workflowType: String, roomID: UUID) {
        postEvent(.workflowStarted(workflowType: workflowType, roomID: roomID))
    }

    /// 문서 생성 완료 (WorkflowOrchestrator artifact 완료 시점)
    func notifyDocumentCreated(documentType: String, roomID: UUID) {
        postEvent(.documentCreated(documentType: documentType, roomID: roomID))
    }

    /// handleWorkroomAction(.handoffFile) / ArtifactCardView reuse
    func notifyArtifactReuseRequested(artifactID: String, roomID: UUID) {
        postEvent(.artifactReuseRequested(artifactID: artifactID, roomID: roomID))
    }

    /// AgentWindowManager room 전환 시
    func notifyRoomSwitched(fromRoomID: UUID, toRoomID: UUID) {
        postEvent(.multiRoomSwitched(fromRoomID: fromRoomID, toRoomID: toRoomID))
    }

    // MARK: - Core Event Processing

    func postEvent(_ event: WorkroomCharacterEvent) {
        Task {
            await processEvent(event)
        }
    }

    private func processEvent(_ event: WorkroomCharacterEvent) async {
        await CharacterReactionEngine.shared.processEvent(event, delegate: delegate)

        // AgentWindowManager.agentEmotions 직접 업데이트
        // delegate가 없어도 emotion state는 반영한다
        if let reaction = CharacterReactionMapping.reactionFor(event) {
            applyEmotionToManager(state: reaction.targetAnimationState, event: event)
        }
    }

    /// AgentWindowManager.agentEmotions[agentID]를 업데이트한다.
    /// 기존 agentEmotions 딕셔너리 타입([String: AnimationState])을 그대로 사용.
    private func applyEmotionToManager(state: AnimationState, event: WorkroomCharacterEvent) {
        let manager = AgentWindowManager.shared

        // roomID 기반으로 현재 active room의 첫 번째 agentID를 찾는다
        let targetRoomID = event.roomID ?? manager.currentRoomID
        let agentID: String

        if let roomID = targetRoomID,
           let room = manager.rooms.first(where: { $0.id == roomID }),
           let firstAgent = room.agentIDs.first {
            agentID = firstAgent
        } else if let current = manager.rooms.first(where: { $0.id == manager.currentRoomID }),
                  let firstAgent = current.agentIDs.first {
            agentID = firstAgent
        } else {
            // agentID를 특정할 수 없으면 no-op
            AppLog.debug("CharacterReactionEventSink: no agentID found for event \(event.id), skipping")
            return
        }

        // 기존 agentEmotions 타입 변경 없이 업데이트
        manager.agentEmotions[agentID] = state
        AppLog.debug("CharacterReactionEventSink: agentEmotions[\(agentID)] = \(state.rawValue)")
    }

    // MARK: - Diagnostics

    func isDelegateAvailable() -> Bool { delegate != nil }

    func diagnosticsSnapshot() -> CharacterReactionDiagnostics {
        CharacterReactionDiagnostics(
            engineAvailable: true,
            delegateRegistered: delegate != nil,
            activeCooldowns: CharacterReactionEngine.shared.cooldownStatus()
        )
    }
}
