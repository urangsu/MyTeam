import Foundation

enum ProductSurfaceTier: String, Sendable, Codable {
    case primary
    case secondary
    case naturalOnly
    case connectionOnly
    case developerOnly
    case hidden
}

enum ProductSurfacePolicy: Sendable {
    static let showsPlannedConnectorsInRelease = false
    static let showsDisabledProButtonInRelease = true
    static let showsPlaceholderCharactersInRelease = false
    static let showsCharacterDLCInRelease = false
    static let allowsExternalWriteStarterActions = false
    static let allowsCalendarWriteSurface = false
    static let allowsMailSendSurface = false
    static let truthfulPrivacyCopyRequired = true

    static func isStarterActionVisibleInRelease(_ actionID: String) -> Bool {
        return StarterActionPolicy.isAllowedStarterActionID(actionID) && !StarterActionPolicy.isBlockedStarterActionID(actionID)
    }

    static func characterVisibilityInRelease(_ characterID: String) -> Bool {
        let canonical = CharacterIDNormalizer.canonicalID(characterID)
        if canonical == "chiko" {
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

    static func tier(for descriptor: MyTeamToolDescriptor) -> ProductSurfaceTier {
        switch descriptor.id {
        case "briefing.today",
             "document.meetingMinutes",
             "finance.krx.stockPrice",
             "finance.krx.index",
             "news.search",
             "law.search":
            return .primary
        case "document.rewrite":
            return .secondary
        case "finance.company.statement",
             "dart.disclosures.search",
             "weather.current",
             "calendar.events.today":
            return .naturalOnly
        case "spreadsheet.postprocess",
             "spreadsheet.googleSheets.read",
             "spreadsheet.merge":
            return .hidden
        case "voice.supertonic.preview",
             "voice.bubbleSpeech.preview":
            return .developerOnly
        default:
            if descriptor.category == .voice {
                return .developerOnly
            }
            if descriptor.category == .spreadsheet {
                return .hidden
            }
            return descriptor.isUserFacing ? .secondary : .hidden
        }
    }

    static func shouldShowInHomePrimary(_ descriptor: MyTeamToolDescriptor) -> Bool {
        descriptor.isUserFacing && tier(for: descriptor) == .primary
    }

    static func shouldShowInHomeSecondary(_ descriptor: MyTeamToolDescriptor) -> Bool {
        descriptor.isUserFacing && tier(for: descriptor) == .secondary
    }

    static func shouldShowInConnectionSection(
        _ descriptor: MyTeamToolDescriptor,
        state: ToolExecutionState
    ) -> Bool {
        guard descriptor.isUserFacing else { return false }
        switch tier(for: descriptor) {
        case .primary, .secondary, .naturalOnly, .connectionOnly:
            break
        case .developerOnly, .hidden:
            return false
        }

        switch state {
        case .needsConnection, .needsAssistantConnection, .needsValidation:
            return true
        default:
            return false
        }
    }
}
