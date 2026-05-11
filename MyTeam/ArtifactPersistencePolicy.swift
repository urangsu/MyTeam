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
        case .dryRun, .blocked, .failed:
            return false
        }
    }
}
