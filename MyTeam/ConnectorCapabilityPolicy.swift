import Foundation

struct ConnectorCapabilityDecision: Equatable {
    enum Status: String, Codable {
        case allowed
        case unavailable
        case requiresApproval
        case blocked
    }

    let status: Status
    let message: String
}

enum ConnectorTokenState: String, Codable {
    case unknown
    case connected
    case disconnected
}

enum ConnectorCapabilityPolicy {
    static func evaluate(
        _ capability: AssistantCapability,
        tokenState: ConnectorTokenState = .unknown
    ) -> ConnectorCapabilityDecision {
        switch capability {
        case .calendarRead:
            if tokenState == .connected {
                return .init(status: .allowed, message: "Google Calendar 읽기 가능")
            }
            return .init(status: .unavailable, message: "Google Calendar 연결 후 사용할 수 있습니다.")

        case .mailMetadataRead:
            return .init(status: .unavailable, message: "메일 메타데이터는 준비 중입니다.")

        case .mailBodyRead, .mailSummarize, .mailDraft:
            return .init(status: .requiresApproval, message: "이 작업은 추가 확인이 필요합니다.")

        case .mailSend, .calendarCreate, .calendarModify, .destructiveFileAction, .automaticLogin:
            return .init(status: .blocked, message: "이 작업은 안전 정책상 자동 실행하지 않습니다.")

        case .answer, .localSkill, .llmGeneration, .artifactCreation, .dailyBriefingPreview, .userInitiatedOAuth:
            return .init(status: .allowed, message: "실행 가능합니다.")
        }
    }

    static func evaluate(
        _ capability: AssistantConnector.Capability,
        tokenState: ConnectorTokenState = .unknown
    ) -> ConnectorCapabilityDecision {
        evaluate(capability.assistantCapability, tokenState: tokenState)
    }
}

extension ConnectorCapabilityDecision.Status {
    var toolExecutionStatus: ToolExecutionDecision.Status {
        switch self {
        case .allowed: return .allowed
        case .unavailable: return .unavailable
        case .requiresApproval: return .requiresApproval
        case .blocked: return .blocked
        }
    }
}

private extension AssistantConnector.Capability {
    var assistantCapability: AssistantCapability {
        switch self {
        case .readCalendarEvents: return .calendarRead
        case .readEmailMetadata: return .mailMetadataRead
        case .readEmailBody: return .mailBodyRead
        case .summarizeEmail: return .mailSummarize
        case .createDraft: return .mailDraft
        case .sendEmail: return .mailSend
        case .createCalendarEvent: return .calendarCreate
        case .modifyCalendarEvent: return .calendarModify
        case .deleteItem: return .destructiveFileAction
        }
    }
}
