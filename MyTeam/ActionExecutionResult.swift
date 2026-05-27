import Foundation

enum ActionExecutionStatus: String, Codable, Sendable {
    case completed
    case prepared
    case approvalRequired
    case queued
    case failed
}

struct ActionExecutionResult: Codable, Sendable, Equatable {
    let status: ActionExecutionStatus
    let message: String
    let requiresApproval: Bool
    let followUpPrompt: String?
    let artifactID: String?
    let actionHandlerID: String?
    let failureCode: String?

    static func completed(_ message: String, handlerID: ActionHandlerID? = nil, artifactID: String? = nil) -> ActionExecutionResult {
        ActionExecutionResult(
            status: .completed,
            message: message,
            requiresApproval: false,
            followUpPrompt: nil,
            artifactID: artifactID,
            actionHandlerID: handlerID?.rawValue,
            failureCode: nil
        )
    }

    static func approvalNeeded(_ message: String, prompt: String, handlerID: ActionHandlerID) -> ActionExecutionResult {
        ActionExecutionResult(
            status: .approvalRequired,
            message: message,
            requiresApproval: true,
            followUpPrompt: prompt,
            artifactID: nil,
            actionHandlerID: handlerID.rawValue,
            failureCode: nil
        )
    }

    static func prepared(_ message: String, prompt: String, handlerID: ActionHandlerID? = nil) -> ActionExecutionResult {
        ActionExecutionResult(
            status: .prepared,
            message: message,
            requiresApproval: false,
            followUpPrompt: prompt,
            artifactID: nil,
            actionHandlerID: handlerID?.rawValue,
            failureCode: nil
        )
    }

    static func queued(_ message: String, prompt: String, handlerID: ActionHandlerID? = nil) -> ActionExecutionResult {
        ActionExecutionResult(
            status: .queued,
            message: message,
            requiresApproval: false,
            followUpPrompt: prompt,
            artifactID: nil,
            actionHandlerID: handlerID?.rawValue,
            failureCode: nil
        )
    }

    static func failed(
        _ message: String,
        handlerID: ActionHandlerID? = nil,
        failureCode: String
    ) -> ActionExecutionResult {
        ActionExecutionResult(
            status: .failed,
            message: message,
            requiresApproval: false,
            followUpPrompt: nil,
            artifactID: nil,
            actionHandlerID: handlerID?.rawValue,
            failureCode: failureCode
        )
    }
}
