import Foundation

enum ActionHandlerID: String, Codable, Sendable {
    case calendarDraft
    case replyDraft
    case todoCreate
    case openMap
    case openBooking
    case saveMemo
    case createDocument
    case summarizeArtifact
}

enum ApprovalBinder {
    static func requiresApproval(for handlerID: ActionHandlerID) -> Bool {
        switch handlerID {
        case .calendarDraft, .openBooking:
            return true
        case .replyDraft, .todoCreate, .openMap, .saveMemo, .createDocument, .summarizeArtifact:
            return false
        }
    }
}
