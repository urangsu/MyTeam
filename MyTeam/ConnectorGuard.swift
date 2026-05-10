import Foundation

struct ToolExecutionDecision: Equatable {
    enum Status: String, Codable {
        case allowed
        case requiresApproval
        case blocked
        case unavailable
    }

    let status: Status
    let message: String
}

enum ConnectorGuard {
    static func evaluate(_ request: ToolExecutionRequest) -> ToolExecutionDecision {
        var finalDecision = ToolExecutionDecision(status: .allowed, message: "실행 가능합니다.")

        for capability in request.requiredCapabilities {
            let decision = evaluateReadCapability(capability)
            switch decision.status {
            case .blocked:
                return decision
            case .requiresApproval:
                if finalDecision.status == .allowed || finalDecision.status == .unavailable {
                    finalDecision = decision
                }
            case .unavailable:
                if finalDecision.status == .allowed {
                    finalDecision = decision
                }
            case .allowed:
                break
            }
        }

        return finalDecision
    }

    static func evaluateReadCapability(_ capability: AssistantCapability) -> ToolExecutionDecision {
        switch capability {
        case .calendarRead:
            if GoogleOAuthTokenStore.shared.hasToken(for: .googleCalendar) {
                return ToolExecutionDecision(
                    status: .allowed,
                    message: "Google Calendar 읽기 가능"
                )
            }
            return ToolExecutionDecision(
                status: .unavailable,
                message: "Google Calendar 연결 후 사용할 수 있습니다."
            )
        case .mailMetadataRead:
            return ToolExecutionDecision(
                status: .unavailable,
                message: "메일 메타데이터는 준비 중입니다."
            )
        case .mailBodyRead, .mailSummarize, .mailDraft:
            return ToolExecutionDecision(
                status: .requiresApproval,
                message: "이 작업은 추가 확인이 필요합니다."
            )
        case .mailSend, .calendarCreate, .calendarModify, .destructiveFileAction, .automaticLogin:
            return ToolExecutionDecision(
                status: .blocked,
                message: "이 작업은 현재 버전에서 자동 실행할 수 없습니다."
            )
        case .answer, .localSkill, .llmGeneration, .artifactCreation, .dailyBriefingPreview, .userInitiatedOAuth:
            return ToolExecutionDecision(
                status: .allowed,
                message: "실행 가능합니다."
            )
        }
    }
}
