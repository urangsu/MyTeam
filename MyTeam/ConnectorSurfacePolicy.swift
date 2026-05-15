import Foundation

enum ConnectorCapability: String, Sendable, Codable {
    case read = "read"
    case calendar = "calendar"
    case mail = "mail"
    case externalUpload = "externalUpload"
    case fileDelete = "fileDelete"
}

enum ConnectorSurfacePolicy: Sendable {
    static let blockedCapabilitiesInRelease: Set<ConnectorCapability> = [.calendar, .mail, .externalUpload, .fileDelete]

    static func isVisibleInRelease(_ capability: ConnectorCapability) -> Bool {
        return !blockedCapabilitiesInRelease.contains(capability)
    }

    static func isWriteBlocked(_ capability: ConnectorCapability) -> Bool {
        switch capability {
        case .calendar, .mail, .externalUpload, .fileDelete:
            return true
        case .read:
            return false
        }
    }

    static func isCapabilityAvailable(_ toolName: String, capability: ConnectorCapability) -> Bool {
        if !isVisibleInRelease(capability) {
            return false
        }
        if isWriteBlocked(capability) {
            return false
        }
        return true
    }
}
