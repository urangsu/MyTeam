import Foundation

struct DelegationContract: Identifiable, Equatable {
    enum Scope: String, Codable {
        case answerOnly
        case localSkill
        case llmSkill
        case artifactCreation
        case toolExecution
        case externalWrite
        case payment
        case login
        case destructive
    }

    enum Status: String, Codable {
        case draft
        case awaitingApproval
        case approved
        case denied
        case expired
        case completed
        case cancelled
    }

    let id: UUID
    let roomID: UUID
    let userMessagePreview: String
    let goal: String
    let allowedScopes: [Scope]
    let blockedScopes: [Scope]
    let requiresReapprovalScopes: [Scope]
    let expectedOutputs: [String]
    let status: Status
    let createdAt: Date
    let expiresAt: Date?

    func updating(
        status: Status,
        createdAt: Date? = nil,
        expiresAt: Date? = nil
    ) -> DelegationContract {
        DelegationContract(
            id: id,
            roomID: roomID,
            userMessagePreview: userMessagePreview,
            goal: goal,
            allowedScopes: allowedScopes,
            blockedScopes: blockedScopes,
            requiresReapprovalScopes: requiresReapprovalScopes,
            expectedOutputs: expectedOutputs,
            status: status,
            createdAt: createdAt ?? self.createdAt,
            expiresAt: expiresAt ?? self.expiresAt
        )
    }
}
