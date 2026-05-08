import Foundation

struct TeamCollaborationStatus: Equatable {
    enum Kind {
        case idle
        case thinking
        case planning
        case gathering
        case writing
        case generatingArtifact
        case waitingForUser
        case completed
        case failed
    }

    let kind: Kind
    let title: String
    let detail: String
    let agentName: String?
}
