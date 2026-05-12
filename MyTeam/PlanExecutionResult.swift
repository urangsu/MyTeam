import Foundation

struct PlanExecutionResult: Equatable {
    enum Status: String {
        case completed
        case failed
        case cancelled
        case fellBackToLegacy
    }

    enum FailureReason: String, Equatable {
        case none
        case recoverableRuntimeError
        case verificationFailed
        case safetyBlocked
        case budgetBlocked
        case cancelled
    }

    let status: Status
    let message: String
    let artifactID: UUID?
    let failureReason: FailureReason

    /// artifact count for diagnostics aggregation
    /// - completed + artifactID → 1
    /// - completed + no artifactID → 0
    /// - fellBackToLegacy + artifactID → 1
    /// - fellBackToLegacy + no artifactID → 0
    /// - failed / cancelled → 0
    var artifactCountForDiagnostics: Int {
        switch status {
        case .completed, .fellBackToLegacy:
            return artifactID == nil ? 0 : 1
        case .failed, .cancelled:
            return 0
        }
    }
}
