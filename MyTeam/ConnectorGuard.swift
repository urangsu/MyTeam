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
        if request.requiredCapabilities.contains(.mailSend)
            || request.requiredCapabilities.contains(.calendarCreate)
            || request.requiredCapabilities.contains(.calendarModify)
            || request.requiredCapabilities.contains(.destructiveFileAction)
            || request.requiredCapabilities.contains(.automaticLogin) {
            return ToolExecutionDecision(
                status: .blocked,
                message: "이 작업은 현재 버전에서 자동 실행할 수 없습니다."
            )
        }

        if request.requiredCapabilities.contains(.mailBodyRead)
            || request.requiredCapabilities.contains(.mailSummarize)
            || request.requiredCapabilities.contains(.mailDraft) {
            return ToolExecutionDecision(
                status: .requiresApproval,
                message: "이 작업은 추가 확인이 필요합니다."
            )
        }

        return ToolExecutionDecision(
            status: .allowed,
            message: "실행 가능합니다."
        )
    }
}
