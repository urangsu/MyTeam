import Foundation

struct ToolExecutionRequest: Equatable {
    enum ToolKind: String, Codable {
        case readFile
        case writeArtifact
        case calendarRead
        case gmailMetadataRead
        case webFetch
    }

    let kind: ToolKind
    let roomID: UUID
    let requiredCapabilities: [AssistantCapability]
    let riskLevel: RiskLevel
}

enum ToolExecutionLayer {
    static func preflight(_ request: ToolExecutionRequest) -> ToolExecutionDecision {
        ConnectorGuard.evaluate(request)
    }
}
