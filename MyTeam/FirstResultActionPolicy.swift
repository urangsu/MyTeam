import Foundation

enum ArtifactState: String, Sendable, Codable {
    case valid = "valid"
    case metadataOnly = "metadataOnly"
    case missingFile = "missingFile"
    case hashMismatch = "hashMismatch"
    case wrongRoom = "wrongRoom"
    case invalidPath = "invalidPath"
}

enum FirstResultActionPolicy: Sendable {
    static func allowedActions(for state: ArtifactState) -> [String] {
        switch state {
        case .valid:
            return ["summary", "table", "checklist", "revealInFinder"]
        case .metadataOnly:
            return []
        case .missingFile, .hashMismatch, .wrongRoom, .invalidPath:
            return []
        }
    }

    static func isActionAllowed(_ action: String, for state: ArtifactState) -> Bool {
        return allowedActions(for: state).contains(action)
    }

    static func defaultActionForState(_ state: ArtifactState) -> String? {
        switch state {
        case .valid:
            return "summary"
        case .metadataOnly, .missingFile, .hashMismatch, .wrongRoom, .invalidPath:
            return nil
        }
    }
}
