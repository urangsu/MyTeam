import Foundation

struct RouteTrace: Identifiable, Equatable {
    enum Step: String, Codable {
        case goalInterpreted
        case skillMatched
        case disabledSkillMatched
        case localSkillHandled
        case dailyBriefingDetected
        case dailyBriefingCompleted
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
        case universalDocumentDetected
        case contextGateEvaluated
        case recentArtifactReferenced
        case universalDocumentGenerated
        case universalDocumentSaved
        case planRunnerStarted
        case planRunnerCompleted
        case planRunnerFallback
        case planRunnerFailed
        case routeResolved
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
