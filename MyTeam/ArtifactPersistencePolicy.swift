import Foundation

// MARK: - ArtifactPersistencePolicy

enum ArtifactPersistencePolicy {
    /// artifact를 index에 추가할지 결정
    static func shouldIndexArtifact(resultStatus: ToolResultStatus) -> Bool {
        resultStatus == .succeeded
    }

    /// artifact를 저장할지 결정
    static func shouldPersist(resultStatus: ToolResultStatus) -> Bool {
        resultStatus == .succeeded
    }

    /// dryRun 결과는 artifact success로 집계하지 않음
    static func isSuccessfulResult(_ status: ToolResultStatus) -> Bool {
        switch status {
        case .succeeded:
            return true
        case .dryRun, .blocked, .failed, .cancelled,
             .approvalRequired, .planned, .unavailable:
            return false
        }
    }

    #if DEBUG
    /// Policy consistency check for debugging
    static func debugPolicyChecks() -> [String] {
        var issues: [String] = []

        // Check: only .succeeded should allow persistence
        let persistenceStatuses: [ToolResultStatus] = [.succeeded, .dryRun, .blocked, .failed, .cancelled, .approvalRequired, .planned, .unavailable]
        for status in persistenceStatuses {
            let shouldPersist = Self.shouldPersist(resultStatus: status)
            let isSucceeded = (status == .succeeded)
            if shouldPersist != isSucceeded {
                issues.append("shouldPersist(\(status.rawValue)) = \(shouldPersist), expected \(isSucceeded)")
            }
        }

        // Check: only .succeeded should allow indexing
        for status in persistenceStatuses {
            let shouldIndex = Self.shouldIndexArtifact(resultStatus: status)
            let isSucceeded = (status == .succeeded)
            if shouldIndex != isSucceeded {
                issues.append("shouldIndexArtifact(\(status.rawValue)) = \(shouldIndex), expected \(isSucceeded)")
            }
        }

        // Check: .succeeded should be successful
        for status in persistenceStatuses {
            let isSuccess = Self.isSuccessfulResult(status)
            let shouldBe = (status == .succeeded)
            if isSuccess != shouldBe {
                issues.append("isSuccessfulResult(\(status.rawValue)) = \(isSuccess), expected \(shouldBe)")
            }
        }

        return issues
    }
    #endif
}

struct ArtifactWorkflowContext: Sendable, Equatable {
    let roomID: UUID?
    let workflowID: UUID
}

enum ArtifactWorkflowOwnership {
    @MainActor
    static func workflowID(for roomID: UUID, manager: AgentWindowManager) -> UUID {
        manager.currentWorkflowID(for: roomID) ?? UUID()
    }

    @MainActor
    static func currentContext(
        manager: AgentWindowManager
    ) -> ArtifactWorkflowContext {
        guard let roomID = manager.currentRoomID else {
            return ArtifactWorkflowContext(roomID: nil, workflowID: UUID())
        }
        return context(for: roomID, manager: manager)
    }

    @MainActor
    static func context(
        for roomID: UUID,
        manager: AgentWindowManager
    ) -> ArtifactWorkflowContext {
        ArtifactWorkflowContext(
            roomID: roomID,
            workflowID: workflowID(for: roomID, manager: manager)
        )
    }
}
