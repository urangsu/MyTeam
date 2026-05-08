import Foundation

struct DelegationModeState: Equatable {
    enum Status: String, Codable {
        case inactive
        case draft
        case awaitingApproval
        case active
        case paused
        case completed
        case cancelled
        case expired
    }

    let roomID: UUID
    let status: Status
    let contractID: UUID?
    let title: String
    let detail: String
    let updatedAt: Date

    func updating(
        status: Status,
        contractID: UUID? = nil,
        title: String? = nil,
        detail: String? = nil,
        updatedAt: Date = Date()
    ) -> DelegationModeState {
        DelegationModeState(
            roomID: roomID,
            status: status,
            contractID: contractID ?? self.contractID,
            title: title ?? self.title,
            detail: detail ?? self.detail,
            updatedAt: updatedAt
        )
    }
}
