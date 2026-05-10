import Foundation

struct PlanExecutionResult: Equatable {
    enum Status: String {
        case completed
        case failed
        case cancelled
        case fellBackToLegacy
    }

    let status: Status
    let message: String
    let artifactID: UUID?
}
