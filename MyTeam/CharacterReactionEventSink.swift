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

enum WorkflowCompletionRoomResolver {
    nonisolated static func roomID(from userInfo: [AnyHashable: Any]?) -> UUID? {
        if let roomID = userInfo?["roomID"] as? UUID {
            return roomID
        }
        if let rawRoomID = userInfo?["roomID"] as? String {
            return UUID(uuidString: rawRoomID)
        }
        return nil
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
            guard let roomID = WorkflowCompletionRoomResolver.roomID(from: notification.userInfo) else {
                AppLog.warning("CharacterReactionEventSink: workflowCompleted roomID 없음 — 반응 생략")
                return
            }

            Task { @MainActor in
                self.notifyDocumentCreated(documentType: "workflowArtifact", roomID: roomID)
            }
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

    // MARK: - Round 256A-260Z: Extended Events

    /// 파일 읽기 시작 (Observation / Finder 입력 시)
    func notifyFileReadStarted(filename: String, roomID: UUID) {
        resetIdleTimer(roomID: roomID)
        postEvent(.fileReadStarted(filename: filename, roomID: roomID))
    }

    /// 결과 검증 중 이상 감지 (WorkflowEngine result 검증 시)
    func notifyVerificationWarning(detail: String, roomID: UUID) {
        resetIdleTimer(roomID: roomID)
        postEvent(.verificationWarning(detail: detail, roomID: roomID))
    }

    /// 결과 검증 실패 (WorkflowEngine validation 실패 시)
    func notifyVerificationFailed(detail: String, roomID: UUID) {
        resetIdleTimer(roomID: roomID)
        postEvent(.verificationFailed(detail: detail, roomID: roomID))
    }

    /// 승인 대기 중 (PendingApprovalStore 등록 시)
    func notifyApprovalWaiting(taskID: String, roomID: UUID) {
        postEvent(.approvalWaiting(taskID: taskID, roomID: roomID))
    }

    /// 로컬 스킬 or assistOnly 완료 시
    func notifyTaskCompleted(skillID: String, roomID: UUID) {
        resetIdleTimer(roomID: roomID)
        postEvent(.taskCompleted(skillID: skillID, roomID: roomID))
    }

    /// 오류 발생 후 재시도 시작 시
    func notifyErrorRecoveryStarted(roomID: UUID) {
        postEvent(.errorRecoveryStarted(roomID: roomID))
    }

    // MARK: - Idle Timer (5분 비활성 → sleeping)

    private var idleTimer: Timer?
    private let idleTimeoutSeconds: TimeInterval = 300

    private func resetIdleTimer(roomID: UUID) {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleTimeoutSeconds, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [self] in
                let rid = AgentWindowManager.shared.currentRoomID ?? roomID
                self.postEvent(.longIdleTriggered(roomID: rid))
            }
        }
    }

    // MARK: - Core Event Processing

    func postEvent(_ event: WorkroomCharacterEvent) {
        Task {
            await processEvent(event)
        }
    }

    private func processEvent(_ event: WorkroomCharacterEvent) async {
        let agentID = targetAgentID(for: event)
        await CharacterReactionEngine.shared.processEvent(
            event,
            agentID: agentID,
            delegate: delegate
        )

        // AgentWindowManager.agentEmotions 직접 업데이트
        // delegate가 없어도 emotion state는 반영한다
        if let agentID, let reaction = CharacterReactionMapping.reactionFor(event) {
            applyEmotionToManager(state: reaction.targetAnimationState, agentID: agentID)
        }
    }

    /// AgentWindowManager.agentEmotions[agentID]를 업데이트한다.
    /// 기존 agentEmotions 딕셔너리 타입([String: AnimationState])을 그대로 사용.
    private func targetAgentID(for event: WorkroomCharacterEvent) -> String? {
        let manager = AgentWindowManager.shared
        let targetRoomID = event.roomID ?? manager.currentRoomID
        if let roomID = targetRoomID,
           let room = manager.rooms.first(where: { $0.id == roomID }),
           let firstAgent = room.agentIDs.first {
            return firstAgent
        } else if let current = manager.rooms.first(where: { $0.id == manager.currentRoomID }),
                  let firstAgent = current.agentIDs.first {
            return firstAgent
        }
        AppLog.debug("CharacterReactionEventSink: no agentID found for event \(event.id), skipping")
        return nil
    }

    private func applyEmotionToManager(state: AnimationState, agentID: String) {
        let manager = AgentWindowManager.shared
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
