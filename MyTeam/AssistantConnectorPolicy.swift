import Foundation

enum AssistantConnectorDecision: Equatable {
    case autoAllowed
    case requiresApproval(reason: String)
    case blocked(reason: String)

    var badgeLabel: String {
        switch self {
        case .autoAllowed: return "읽기 준비 중"
        case .requiresApproval: return "승인 필요"
        case .blocked: return "자동 실행 차단"
        }
    }
}

enum AssistantConnectorPolicy {
    static func decision(for capability: AssistantConnector.Capability) -> AssistantConnectorDecision {
        switch capability {
        case .readCalendarEvents, .readEmailMetadata:
            return .autoAllowed
        case .readEmailBody, .summarizeEmail, .createDraft:
            return .requiresApproval(reason: "개인 정보가 포함될 수 있어 확인 후 처리합니다.")
        case .sendEmail, .createCalendarEvent, .modifyCalendarEvent, .deleteItem:
            return .blocked(reason: "현재 버전에서는 자동 실행할 수 없습니다.")
        }
    }

    static func decision(for connector: AssistantConnector) -> AssistantConnectorDecision {
        if connector.capabilities.contains(where: { if case .autoAllowed = decision(for: $0) { return true } else { return false } }) {
            return .autoAllowed
        }
        if connector.capabilities.contains(where: { if case .requiresApproval = decision(for: $0) { return true } else { return false } }) {
            return .requiresApproval(reason: "본문 읽기/초안은 승인 후 사용합니다.")
        }
        return .blocked(reason: "발송/수정/삭제는 현재 차단됩니다.")
    }
}
