import Foundation

enum AssistantConnectorDecision: Equatable {
    case allowed
    case unavailable
    case requiresApproval(reason: String)
    case blocked(reason: String)

    var badgeLabel: String {
        switch self {
        case .allowed: return "사용 가능"
        case .unavailable: return "준비 중"
        case .requiresApproval: return "추가 승인"
        case .blocked: return "현재 차단"
        }
    }
}

enum AssistantConnectorPolicy {
    static func decision(for capability: AssistantConnector.Capability) -> AssistantConnectorDecision {
        let decision = ConnectorCapabilityPolicy.evaluate(capability)
        return decision.toAssistantConnectorDecision
    }

    static func decision(for connector: AssistantConnector) -> AssistantConnectorDecision {
        let decisions = connector.capabilities.map { capability in
            Self.decision(for: capability)
        }
        if decisions.contains(where: { if case .blocked = $0 { return true } else { return false } }) {
            return .blocked(reason: "이 작업은 안전 정책상 자동 실행하지 않습니다.")
        }
        if decisions.contains(where: { if case .requiresApproval = $0 { return true } else { return false } }) {
            return .requiresApproval(reason: "추가 확인이 필요합니다.")
        }
        if decisions.contains(where: { if case .unavailable = $0 { return true } else { return false } }) {
            return .unavailable
        }
        return .allowed
    }
}

private extension ConnectorCapabilityDecision {
    var toAssistantConnectorDecision: AssistantConnectorDecision {
        switch status {
        case .allowed:
            return .allowed
        case .unavailable:
            return .unavailable
        case .requiresApproval:
            return .requiresApproval(reason: message)
        case .blocked:
            return .blocked(reason: message)
        }
    }
}
