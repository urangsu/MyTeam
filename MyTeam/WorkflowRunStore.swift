import Foundation

// MARK: - WorkflowRunStore
// 워크플로우 실행 기록을 저장·조회한다.
// UI 연결은 다음 단계 — 이번에는 타입 정의와 저장소 골격만.

// MARK: - Supporting Enums

enum WorkflowStatus: String, Codable {
    case running
    case completed
    case failed
    case cancelled
}

enum StepStatus: String, Codable {
    case pending
    case running
    case completed
    case failed
    case skipped
}

// MARK: - Record Types

struct StepExecutionRecord: Identifiable, Codable {
    let id: UUID
    let stepID: String
    let toolName: String
    let inputSummary: String
    var status: StepStatus
    let startedAt: Date
    var endedAt: Date?
    var outputSummary: String?
    var errorMessage: String?
    var evidencePaths: [String]

    init(stepID: String, toolName: String, inputSummary: String) {
        self.id = UUID()
        self.stepID = stepID
        self.toolName = toolName
        self.inputSummary = inputSummary
        self.status = .pending
        self.startedAt = Date()
        self.evidencePaths = []
    }
}

struct WorkflowErrorRecord: Codable {
    let timestamp: Date
    let stepID: String?
    let message: String
    let provider: String?
}

struct AICallRecord: Codable {
    let timestamp: Date
    let provider: String
    let callType: String
    let durationMs: Int
    let success: Bool
}

struct WorkflowRunRecord: Identifiable, Codable {
    let id: UUID               // == workflowID
    let roomID: UUID
    let userMessage: String
    var status: WorkflowStatus
    let startedAt: Date
    var endedAt: Date?
    var steps: [StepExecutionRecord]
    var artifacts: [String]    // artifact 파일 경로 (상대)
    var errors: [WorkflowErrorRecord]
    var providerCalls: [AICallRecord]

    init(workflowID: UUID, roomID: UUID, userMessage: String) {
        self.id = workflowID
        self.roomID = roomID
        self.userMessage = userMessage
        self.status = .running
        self.startedAt = Date()
        self.steps = []
        self.artifacts = []
        self.errors = []
        self.providerCalls = []
    }

    var durationSeconds: Double? {
        guard let end = endedAt else { return nil }
        return end.timeIntervalSince(startedAt)
    }
}

// MARK: - WorkflowRunStore

// @MainActor로 관리: Date() 초기화가 @MainActor 추론되므로 actor 대신 MainActor class 사용.
// 모든 호출자는 await 없이 @MainActor 컨텍스트에서 직접 호출 가능.
@MainActor
final class WorkflowRunStore {
    static let shared = WorkflowRunStore()

    private var records: [UUID: WorkflowRunRecord] = [:]

    private init() {}

    // MARK: - Write

    func begin(workflowID: UUID, roomID: UUID, userMessage: String) {
        records[workflowID] = WorkflowRunRecord(
            workflowID: workflowID,
            roomID: roomID,
            userMessage: userMessage
        )
    }

    func recordStep(workflowID: UUID, step: StepExecutionRecord) {
        records[workflowID]?.steps.append(step)
    }

    func updateStep(workflowID: UUID, stepID: String, update: (inout StepExecutionRecord) -> Void) {
        guard let idx = records[workflowID]?.steps.firstIndex(where: { $0.stepID == stepID }) else { return }
        update(&records[workflowID]!.steps[idx])
    }

    func recordError(workflowID: UUID, stepID: String? = nil, message: String, provider: String? = nil) {
        let err = WorkflowErrorRecord(timestamp: Date(), stepID: stepID, message: message, provider: provider)
        records[workflowID]?.errors.append(err)
    }

    func recordAICall(workflowID: UUID, provider: String, callType: String, durationMs: Int, success: Bool) {
        let call = AICallRecord(timestamp: Date(), provider: provider, callType: callType,
                                durationMs: durationMs, success: success)
        records[workflowID]?.providerCalls.append(call)
    }

    func addArtifact(workflowID: UUID, relativePath: String) {
        records[workflowID]?.artifacts.append(relativePath)
    }

    func finish(workflowID: UUID, status: WorkflowStatus) {
        records[workflowID]?.status = status
        records[workflowID]?.endedAt = Date()
    }

    // MARK: - Read

    func record(for workflowID: UUID) -> WorkflowRunRecord? {
        records[workflowID]
    }

    func allRecords() -> [WorkflowRunRecord] {
        records.values.sorted { $0.startedAt > $1.startedAt }
    }

    func recentRecords(limit: Int = 20) -> [WorkflowRunRecord] {
        Array(allRecords().prefix(limit))
    }

    func records(for roomID: UUID) -> [WorkflowRunRecord] {
        records.values
            .filter { $0.roomID == roomID }
            .sorted { $0.startedAt > $1.startedAt }
    }
}
