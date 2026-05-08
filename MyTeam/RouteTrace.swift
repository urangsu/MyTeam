import Foundation

struct RouteTrace: Identifiable, Equatable {
    enum Step: String, Codable {
        case skillMatched
        case disabledSkillMatched
        case localSkillHandled
        case delegationDetected
        case delegationApproved
        case delegationCancelled
        case delegationResumePrepared
        case delegationResumed
        case delegationResumeBlocked
        case approvalRequired
        case approvalBlocked
        case appLaunchDetected
        case privacyTermsDetected
        case fileCreationDetected
        case intentClassified
        case teamDiscussionSelected
        case directChatSelected
        case blocked
        case fallback
    }

    let id: UUID
    let roomID: UUID
    let step: Step
    let message: String
    let timestamp: Date
}
