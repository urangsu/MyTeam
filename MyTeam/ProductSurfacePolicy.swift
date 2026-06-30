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
    nonisolated static let showsPlannedConnectorsInRelease = false
    nonisolated static let showsDisabledProButtonInRelease = true
    nonisolated static let showsPlaceholderCharactersInRelease = false
    nonisolated static let showsCharacterDLCInRelease = false
    nonisolated static let allowsExternalWriteStarterActions = false
    nonisolated static let allowsCalendarWriteSurface = false
    nonisolated static let allowsMailSendSurface = false
    nonisolated static let truthfulPrivacyCopyRequired = true

    nonisolated static func isEnabledInCurrentReleaseSurface(_ descriptor: MyTeamToolDescriptor) -> Bool {
        ReleaseLiveProviderGate.isEnabledInCurrentReleaseSurface(toolID: descriptor.id)
    }

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

    nonisolated static func dlcVisibilityInRelease() -> Bool {
        return showsCharacterDLCInRelease
    }

    nonisolated static func proButtonStateInRelease() -> String {
        return showsDisabledProButtonInRelease ? "disabled" : "hidden"
    }

    nonisolated static func tier(for descriptor: MyTeamToolDescriptor) -> ProductSurfaceTier {
        guard isEnabledInCurrentReleaseSurface(descriptor) else {
            return .hidden
        }

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

    nonisolated static func shouldShowInHomePrimary(_ descriptor: MyTeamToolDescriptor) -> Bool {
        descriptor.isUserFacing && tier(for: descriptor) == .primary
    }

    nonisolated static func shouldShowInHomeSecondary(_ descriptor: MyTeamToolDescriptor) -> Bool {
        descriptor.isUserFacing && tier(for: descriptor) == .secondary
    }

    nonisolated static func shouldShowInConnectionSection(
        _ descriptor: MyTeamToolDescriptor,
        state: ToolExecutionState
    ) -> Bool {
        guard descriptor.isUserFacing else { return false }
        guard isEnabledInCurrentReleaseSurface(descriptor) else { return false }
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

enum ReleaseLiveProviderGate: Sendable {
    // Release/App Store defaults are fail-closed until live QA evidence is recorded.
    // Debug/Developer builds keep these paths enabled so QA can still exercise them.
    nonisolated static let workerProductionHealthPassed = false
    nonisolated static let googleLiveQAPassed = false
    nonisolated static let financeLiveQAPassed = false
    nonisolated static let dartLiveQAPassed = false
    nonisolated static let kmaLiveQAPassed = false
    nonisolated static let newsLiveQAPassed = false
    nonisolated static let lawLiveQAPassed = false

    nonisolated static func isEnabledInCurrentReleaseSurface(toolID: String) -> Bool {
        guard FeatureGate.current != .developer else { return true }
        return isApprovedForRelease(toolID: toolID)
    }

    nonisolated static func isApprovedForRelease(toolID: String) -> Bool {
        switch toolID {
        case "news.search":
            return workerProductionHealthPassed && newsLiveQAPassed
        case "law.search":
            return workerProductionHealthPassed && lawLiveQAPassed
        case "finance.krx.stockPrice", "finance.krx.index", "finance.company.statement":
            return workerProductionHealthPassed && financeLiveQAPassed
        case "weather.current":
            return workerProductionHealthPassed && kmaLiveQAPassed
        case "dart.disclosures.search":
            return dartLiveQAPassed
        case "calendar.events.today", "spreadsheet.googleSheets.read":
            return googleLiveQAPassed
        default:
            return true
        }
    }

    nonisolated static func disabledMessage(for descriptor: MyTeamToolDescriptor) -> String {
        switch descriptor.id {
        case "news.search", "law.search", "finance.krx.stockPrice", "finance.krx.index", "finance.company.statement", "weather.current":
            return "이 외부 조회는 출시 전 live QA가 완료될 때까지 Release 표면에서 비활성화됩니다."
        case "dart.disclosures.search":
            return "DART 조회는 개인 키 live QA가 완료될 때까지 Release 표면에서 비활성화됩니다."
        case "calendar.events.today", "spreadsheet.googleSheets.read":
            return "Google 읽기 연결은 live OAuth QA가 완료될 때까지 Release 표면에서 비활성화됩니다."
        default:
            return "\(descriptor.displayName)은 현재 Release 표면에서 사용할 수 없습니다."
        }
    }
}
