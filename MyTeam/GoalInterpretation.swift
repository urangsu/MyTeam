import Foundation

struct GoalInterpretation: Identifiable, Equatable {
    enum GoalType: String, Codable {
        case dailyBriefing
        case documentWork
        case fileCreation
        case mailBriefing
        case mailAction
        case calendarBriefing
        case calendarAction
        case teamDiscussion
        case directAnswer
        case connectorSetup
        case appLaunch
        case privacyTerms
        case unknown
    }

    enum Confidence: String, Codable {
        case high
        case medium
        case low
    }

    let id: UUID
    let userMessagePreview: String
    let goalType: GoalType
    let title: String
    let inferredOutputs: [String]
    let requiredCapabilities: [AssistantCapability]
    let missingInputs: [String]
    let confidence: Confidence
    let requiresClarification: Bool
    let createdAt: Date
}
