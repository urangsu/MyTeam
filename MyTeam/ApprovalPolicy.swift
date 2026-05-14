import Foundation

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
