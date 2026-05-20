import Foundation

// MARK: - Round 246A: PendingApprovalRequest foundation (P0-3)
// 승인 재실행 UI는 246B에서 구현. 246A는 모델 + 인터페이스 선언만.

enum ApprovalStatus: String, Codable {
    case pending
    case approved
    case rejected
    case expired
}

struct PendingApprovalRequest: Identifiable, Sendable {
    let id: UUID
    let roomID: UUID
    let toolName: String
    let input: [String: String]
    let riskLevel: ToolRiskLevel
    let reason: String
    let createdAt: Date
    let expiresAt: Date?
    var status: ApprovalStatus
}

/// 246B에서 구현: 승인된 request를 재실행
/// 인터페이스를 선언해 두어 WorkflowOrchestrator가 참조 가능하게 함.
protocol ApprovalExecutionHandler: AnyObject {
    func executeApproved(requestID: UUID) async
}

// MARK: - ApprovalDecision

enum ApprovalDecision: Equatable {
    case autoAllowed
    case requiresApproval(reason: String)
    case blocked(reason: String)
}

enum ApprovalPolicy {
    static func decision(for scope: DelegationContract.Scope) -> ApprovalDecision {
        switch scope {
        case .answerOnly, .localSkill, .llmSkill, .artifactCreation:
            return .autoAllowed
        case .toolExecution:
            return .requiresApproval(reason: "도구 실행은 작업 내용에 따라 확인이 필요합니다.")
        case .externalWrite:
            return .requiresApproval(reason: "외부 전송은 실행 전 확인이 필요합니다.")
        case .payment, .login, .destructive:
            return .blocked(reason: "이 작업은 안전 정책상 자동 실행하지 않습니다.")
        }
    }

    static func decision(for scopes: [DelegationContract.Scope]) -> [ApprovalDecision] {
        scopes.map { scope in
            decision(for: scope)
        }
    }
}
