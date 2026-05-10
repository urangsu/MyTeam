import Foundation

enum LocalTaskBriefingAction: String, Codable, Equatable {
    case summarizeRecentFile
    case reuseRecentArtifact
    case summarizeTodayTasks
    case resumeDelegation
    case askContinuation
}

@MainActor
enum LocalTaskBriefingActionPolicy {
    static func isSupported(
        _ action: LocalTaskBriefingAction,
        roomID: UUID? = nil,
        manager: AgentWindowManager = .shared
    ) -> Bool {
        let resolvedRoomID = roomID ?? manager.currentRoomID
        switch action {
        case .summarizeRecentFile:
            guard let resolvedRoomID,
                  let fileResult = manager.lastFileIntakeResult(for: resolvedRoomID) else {
                return false
            }
            return fileResult.status == .ready
        case .reuseRecentArtifact:
            guard let resolvedRoomID else { return false }
            return RecentArtifactContentResolver.canResolveLatestMarkdownArtifact(
                roomID: resolvedRoomID,
                manager: manager
            )
        case .summarizeTodayTasks:
            return true
        case .resumeDelegation:
            guard let resolvedRoomID else { return false }
            if let state = manager.delegationModeState(for: resolvedRoomID), state.status == .awaitingApproval {
                return true
            }
            return manager.pendingDelegatedExecutionRequest(for: resolvedRoomID) != nil
        case .askContinuation:
            return true
        }
    }
}
