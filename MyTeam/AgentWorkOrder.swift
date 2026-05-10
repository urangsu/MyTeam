import Foundation

extension AgentWorkOrder {
    init(agentID: String, subTask: String) {
        self.init(
            agentID: agentID,
            subTask: subTask,
            role: nil,
            title: nil,
            instruction: nil,
            inputKeys: nil,
            outputKey: nil,
            verificationLevel: nil,
            maxRetries: nil
        )
    }

    var pipelineRole: AgentRole? { role }
    var pipelineTitle: String { title ?? subTask }
    var pipelineInstruction: String { instruction ?? subTask }
    var pipelineInputKeys: [String] { inputKeys ?? [] }
    var pipelineOutputKey: String { outputKey ?? "output" }
    var pipelineVerificationLevel: VerificationLevel { verificationLevel ?? .none }
    var pipelineMaxRetries: Int { maxRetries ?? 0 }

    init(
        role: AgentRole,
        title: String,
        instruction: String,
        inputKeys: [String],
        outputKey: String,
        verificationLevel: VerificationLevel,
        maxRetries: Int
    ) {
        self.init(
            agentID: role.rawValue,
            subTask: instruction,
            role: role,
            title: title,
            instruction: instruction,
            inputKeys: inputKeys,
            outputKey: outputKey,
            verificationLevel: verificationLevel,
            maxRetries: maxRetries
        )
    }
}
