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
}
