import Foundation

// MARK: - AgentEventStream
// 워크플로우 진행 상태를 ChatLog에 억지로 넣지 않고 이벤트로 관리한다.
// UI는 이벤트를 렌더링하고, 완료/실패 결과만 ChatLog에 남긴다.
//
// [현재 단계] 타입 정의만 추가.
//            기존 코드 교체는 다음 단계.

// MARK: - AgentEventType

enum AgentEventType: String, Codable {
    case userMessageSubmitted
    case routeDecided
    case workflowStarted
    case modelCallStarted
    case modelCallCompleted
    case modelCallFailed
    case toolCallStarted
    case toolCallFinished
    case artifactCreated
    case validationFailed
    case workflowCancelled
    case workflowCompleted
}

// MARK: - AgentEvent

struct AgentEvent: Identifiable, Codable {
    let id: UUID
    let type: AgentEventType
    let workflowID: UUID?
    let roomID: UUID?
    let timestamp: Date
    let payload: AgentEventPayload

    init(
        type: AgentEventType,
        workflowID: UUID? = nil,
        roomID: UUID? = nil,
        payload: AgentEventPayload = .empty
    ) {
        self.id = UUID()
        self.type = type
        self.workflowID = workflowID
        self.roomID = roomID
        self.timestamp = Date()
        self.payload = payload
    }
}

// MARK: - AgentEventPayload

struct AgentEventPayload: Codable {
    let agentID: String?
    let agentName: String?
    let toolName: String?
    let stepID: String?
    let message: String?
    let provider: String?
    let artifactPath: String?
    let durationMs: Int?
    let errorMessage: String?

    static let empty = AgentEventPayload()

    init(
        agentID: String? = nil,
        agentName: String? = nil,
        toolName: String? = nil,
        stepID: String? = nil,
        message: String? = nil,
        provider: String? = nil,
        artifactPath: String? = nil,
        durationMs: Int? = nil,
        errorMessage: String? = nil
    ) {
        self.agentID = agentID
        self.agentName = agentName
        self.toolName = toolName
        self.stepID = stepID
        self.message = message
        self.provider = provider
        self.artifactPath = artifactPath
        self.durationMs = durationMs
        self.errorMessage = errorMessage
    }
}

// MARK: - AgentEventBus
// 인메모리 이벤트 버스 — Observer 패턴.
// UI 구독은 다음 단계에서 연결.

actor AgentEventBus {
    static let shared = AgentEventBus()
    private init() {}

    private var recentEvents: [AgentEvent] = []
    private let maxRecentEvents: Int = 100

    // MARK: - Publish

    func publish(_ event: AgentEvent) {
        recentEvents.append(event)
        if recentEvents.count > maxRecentEvents {
            recentEvents.removeFirst(recentEvents.count - maxRecentEvents)
        }
        AppLog.debug("[AgentEvent] \(event.type.rawValue) workflow=\(event.workflowID?.uuidString.prefix(8) ?? "-")")
    }

    // MARK: - Query

    func recentEvents(for workflowID: UUID) -> [AgentEvent] {
        recentEvents.filter { $0.workflowID == workflowID }
    }

    func recentEvents(for roomID: UUID, limit: Int = 20) -> [AgentEvent] {
        Array(recentEvents.filter { $0.roomID == roomID }.suffix(limit))
    }

    func allRecentEvents(limit: Int = 50) -> [AgentEvent] {
        Array(recentEvents.suffix(limit))
    }
}

// MARK: - Convenience Factory Methods

extension AgentEvent {
    static func userMessageSubmitted(roomID: UUID, message: String) -> AgentEvent {
        AgentEvent(type: .userMessageSubmitted, roomID: roomID,
                   payload: AgentEventPayload(message: String(message.prefix(100))))
    }

    static func workflowStarted(workflowID: UUID, roomID: UUID) -> AgentEvent {
        AgentEvent(type: .workflowStarted, workflowID: workflowID, roomID: roomID)
    }

    static func workflowCompleted(workflowID: UUID, roomID: UUID, artifactCount: Int) -> AgentEvent {
        AgentEvent(type: .workflowCompleted, workflowID: workflowID, roomID: roomID,
                   payload: AgentEventPayload(message: "\(artifactCount)개 산출물"))
    }

    static func workflowCancelled(workflowID: UUID, roomID: UUID) -> AgentEvent {
        AgentEvent(type: .workflowCancelled, workflowID: workflowID, roomID: roomID)
    }

    static func modelCallStarted(workflowID: UUID?, provider: String, agentID: String) -> AgentEvent {
        AgentEvent(type: .modelCallStarted, workflowID: workflowID,
                   payload: AgentEventPayload(agentID: agentID, provider: provider))
    }

    static func modelCallFailed(workflowID: UUID?, provider: String, error: String) -> AgentEvent {
        AgentEvent(type: .modelCallFailed, workflowID: workflowID,
                   payload: AgentEventPayload(provider: provider, errorMessage: error))
    }

    static func toolCallStarted(workflowID: UUID, stepID: String, toolName: String) -> AgentEvent {
        AgentEvent(type: .toolCallStarted, workflowID: workflowID,
                   payload: AgentEventPayload(toolName: toolName, stepID: stepID))
    }

    static func toolCallFinished(workflowID: UUID, stepID: String, toolName: String,
                                  durationMs: Int, success: Bool) -> AgentEvent {
        let type: AgentEventType = success ? .toolCallFinished : .validationFailed
        return AgentEvent(type: type, workflowID: workflowID,
                          payload: AgentEventPayload(toolName: toolName, stepID: stepID,
                                                     durationMs: durationMs))
    }

    static func artifactCreated(workflowID: UUID, roomID: UUID, path: String) -> AgentEvent {
        AgentEvent(type: .artifactCreated, workflowID: workflowID, roomID: roomID,
                   payload: AgentEventPayload(artifactPath: path))
    }
}
