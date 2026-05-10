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
        let tokenState: ConnectorTokenState = capability == .calendarRead && GoogleOAuthTokenStore.shared.hasToken(for: .googleCalendar)
            ? .connected
            : (capability == .calendarRead ? .disconnected : .unknown)
        let decision = ConnectorCapabilityPolicy.evaluate(capability, tokenState: tokenState)
        return ToolExecutionDecision(
            status: decision.status.toolExecutionStatus,
            message: decision.message
        )
    }
}
