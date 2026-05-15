import Foundation

enum ArtifactState: String, Sendable, Codable {
    case valid = "valid"
    case missingFile = "missingFile"
    case hashMismatch = "hashMismatch"
    case wrongRoom = "wrongRoom"
}

enum FirstResultActionPolicy: Sendable {
    static func allowedActions(for state: ArtifactState) -> [String] {
        switch state {
        case .valid:
            return ["summary", "table", "checklist", "revealInFinder"]
        case .missingFile, .hashMismatch, .wrongRoom:
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
        case .missingFile, .hashMismatch, .wrongRoom:
            return nil
        }
    }
}
