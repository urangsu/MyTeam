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
    // Round 278 2-A: 승인 후 재실행에 사용할 원본 사용자 메시지. nil(legacy) 시 상태 변경만.
    var originalUserMessage: String? = nil
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
        // Round 278 2-B: ApprovalCopy의 통일된 문구 사용
        switch scope {
        case .answerOnly, .localSkill, .llmSkill, .artifactCreation:
            return .autoAllowed
        case .toolExecution:
            return .requiresApproval(reason: ApprovalCopy.approvalNeededToolExecution)
        case .externalWrite:
            return .requiresApproval(reason: ApprovalCopy.approvalNeededExternalWrite)
        case .payment, .login, .destructive:
            return .blocked(reason: ApprovalCopy.blockedSafetyPolicy)
        }
    }

    static func decision(for scopes: [DelegationContract.Scope]) -> [ApprovalDecision] {
        scopes.map { scope in
            decision(for: scope)
        }
    }
}
