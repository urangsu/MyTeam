import Foundation

struct DelegatedExecutionRequest: Identifiable, Equatable {
    enum Status: String, Codable {
        case pendingApproval
        case readyToResume
        case resumed
        case blocked
        case cancelled
    }

    let id: UUID
    let roomID: UUID
    let contractID: UUID
    let originalMessagePreview: String
    let normalizedExecutionMessage: String
    let routeHint: String?
    let status: Status
    let createdAt: Date

    func updating(status: Status) -> DelegatedExecutionRequest {
        DelegatedExecutionRequest(
            id: id,
            roomID: roomID,
            contractID: contractID,
            originalMessagePreview: originalMessagePreview,
            normalizedExecutionMessage: normalizedExecutionMessage,
            routeHint: routeHint,
            status: status,
            createdAt: createdAt
        )
    }
}
