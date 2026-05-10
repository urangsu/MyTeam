import Foundation

struct LocalTaskBriefingItem: Identifiable, Equatable {
    enum Kind: String, Codable {
        case scheduledTask
        case recentFile
        case recentArtifact
        case pendingApproval
        case pendingDelegation
        case failedWorkflow
        case connectorAction
        case suggestedNextAction
    }

    enum Priority: String, Codable {
        case high
        case normal
        case low
    }

    let id: UUID
    let kind: Kind
    let title: String
    let detail: String
    let priority: Priority
    let createdAt: Date
}
