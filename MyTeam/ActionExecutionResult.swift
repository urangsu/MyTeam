import Foundation

struct ActionExecutionResult: Codable, Sendable, Equatable {
    let status: String
    let message: String
    let requiresApproval: Bool
    let followUpPrompt: String?
    let artifactID: String?
    let actionHandlerID: String?

    static func completed(_ message: String, handlerID: ActionHandlerID? = nil, artifactID: String? = nil) -> ActionExecutionResult {
        ActionExecutionResult(
            status: "completed",
            message: message,
            requiresApproval: false,
            followUpPrompt: nil,
            artifactID: artifactID,
            actionHandlerID: handlerID?.rawValue
        )
    }

    static func approvalNeeded(_ message: String, prompt: String, handlerID: ActionHandlerID) -> ActionExecutionResult {
        ActionExecutionResult(
            status: "approval_required",
            message: message,
            requiresApproval: true,
            followUpPrompt: prompt,
            artifactID: nil,
            actionHandlerID: handlerID.rawValue
        )
    }

    static func queued(_ message: String, prompt: String, handlerID: ActionHandlerID? = nil) -> ActionExecutionResult {
        ActionExecutionResult(
            status: "queued",
            message: message,
            requiresApproval: false,
            followUpPrompt: prompt,
            artifactID: nil,
            actionHandlerID: handlerID?.rawValue
        )
    }
}
