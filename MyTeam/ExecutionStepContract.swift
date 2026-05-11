import CryptoKit
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
    var stableContractID: UUID {
        StableExecutionContractID.uuid(
            namespace: "AgentWorkOrder",
            parts: [
                agentID,
                pipelineRole?.rawValue ?? "nil",
                pipelineOutputKey,
                pipelineInstruction
            ]
        )
    }

    var executionContract: ExecutionStepContract {
        ExecutionStepContract(
            id: stableContractID,
            title: pipelineTitle,
            instruction: pipelineInstruction,
            inputKeys: pipelineInputKeys,
            outputKey: pipelineOutputKey,
            verificationLevel: pipelineVerificationLevel,
            maxRetries: pipelineMaxRetries
        )
    }
}

private enum StableExecutionContractID {
    static func uuid(namespace: String, parts: [String]) -> UUID {
        let seed = ([namespace] + parts).joined(separator: "\u{1f}")
        let digest = SHA256.hash(data: Data(seed.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
