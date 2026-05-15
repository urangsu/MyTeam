import Foundation

enum ProductSurfacePolicy: Sendable {
    static let showsPlannedConnectorsInRelease = false
    static let showsDisabledProButtonInRelease = true
    static let showsPlaceholderCharactersInRelease = false
    static let showsCharacterDLCInRelease = true
    static let allowsExternalWriteStarterActions = false
    static let allowsCalendarWriteSurface = false
    static let allowsMailSendSurface = false
    static let truthfulPrivacyCopyRequired = true

    static func isStarterActionVisibleInRelease(_ actionID: String) -> Bool {
        return !StarterActionPolicy.blockedStarterActionIDs.contains(actionID)
    }

    static func characterVisibilityInRelease(_ characterID: String) -> Bool {
        if characterID == "chiko" {
            return true
        }
        let manifest = CharacterCatalog.assetManifest(for: characterID)
        return !manifest.isPlaceholder
    }

    static func dlcVisibilityInRelease() -> Bool {
        return showsCharacterDLCInRelease
    }

    static func proButtonStateInRelease() -> String {
        return showsDisabledProButtonInRelease ? "disabled" : "hidden"
    }
}
