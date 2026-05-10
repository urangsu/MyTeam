import Foundation

struct ExecutionStepContract: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let instruction: String
    let inputKeys: [String]
    let outputKey: String
    let verificationLevel: VerificationLevel
    let maxRetries: Int
}

extension WorkStep {
    var executionContract: ExecutionStepContract {
        ExecutionStepContract(
            id: id,
            title: title,
            instruction: prompt ?? title,
            inputKeys: inputKeys,
            outputKey: outputKey ?? "output",
            verificationLevel: verificationLevel,
            maxRetries: maxRetries
        )
    }
}

extension AgentWorkOrder {
    var executionContract: ExecutionStepContract {
        ExecutionStepContract(
            id: UUID(uuidString: agentID) ?? UUID(),
            title: pipelineTitle,
            instruction: pipelineInstruction,
            inputKeys: pipelineInputKeys,
            outputKey: pipelineOutputKey,
            verificationLevel: pipelineVerificationLevel,
            maxRetries: pipelineMaxRetries
        )
    }
}
