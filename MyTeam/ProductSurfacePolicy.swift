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
        ReleaseLiveProviderGate.isEnabledInCurrentReleaseSurface(descriptor)
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
    nonisolated static func isEnabledInCurrentReleaseSurface(_ descriptor: MyTeamToolDescriptor) -> Bool {
        guard FeatureGate.current != .developer else { return true }
        return isApprovedForRelease(descriptor)
    }

    nonisolated static func isApprovedForRelease(_ descriptor: MyTeamToolDescriptor) -> Bool {
        switch descriptor.id {
        case "news.search":
            return workerIsRuntimeCompatible && providerIsPass("news")
        case "law.search":
            return workerIsRuntimeCompatible && providerIsPass("law")
        case "finance.krx.stockPrice", "finance.krx.index", "finance.company.statement":
            return workerIsRuntimeCompatible && providerIsPass("finance")
        case "weather.current":
            return workerIsRuntimeCompatible && providerIsPass("kma")
        case "dart.disclosures.search":
            return providerIsApproved("dart")
        case "calendar.events.today", "spreadsheet.googleSheets.read":
            return providerIsPass("google")
        default:
            return isKnownLocalSafeCapability(descriptor)
        }
    }

    private nonisolated static var workerIsRuntimeCompatible: Bool {
        let worker = ReleaseCapabilityManifestStore.bundled.worker
        return worker.contractVersion == 3 && worker.productionHealth == .pass
    }

    private nonisolated static func providerIsPass(_ provider: String) -> Bool {
        ReleaseCapabilityManifestStore.status(for: provider) == .pass
    }

    private nonisolated static func providerIsApproved(_ provider: String) -> Bool {
        ReleaseCapabilityManifestStore.status(for: provider).isApproved
    }

    private nonisolated static func isKnownLocalSafeCapability(_ descriptor: MyTeamToolDescriptor) -> Bool {
        guard descriptor.isImplemented, descriptor.isUserFacing else { return false }
        if let _ = descriptor.requiredCredential { return false }
        guard descriptor.relatedProvider == nil else { return false }

        switch descriptor.permissionLevel {
        case .readOnly, .draftOnly:
            break
        case .writeRequiresApproval, .destructiveRequiresApproval, .externalSendRequiresApproval:
            return false
        }

        switch descriptor.category {
        case .briefing, .document:
            return true
        case .spreadsheet, .externalInfo, .calendar, .mail, .voice, .system:
            return false
        }
    }

    nonisolated static func disabledMessage(for descriptor: MyTeamToolDescriptor) -> String {
        switch descriptor.id {
        case "news.search", "law.search", "finance.krx.stockPrice", "finance.krx.index", "finance.company.statement", "weather.current":
            if !ReleaseCapabilityManifestStore.hasGeneratedManifest {
                return "이 외부 조회는 출시 후보 검증 manifest가 포함될 때까지 Release 표면에서 비활성화됩니다."
            }
            return "이 외부 조회는 출시 전 live QA와 Worker 호환 검증이 완료될 때까지 Release 표면에서 비활성화됩니다."
        case "dart.disclosures.search":
            return "DART 조회는 개인 키 live QA가 완료될 때까지 Release 표면에서 비활성화됩니다."
        case "calendar.events.today", "spreadsheet.googleSheets.read":
            return "Google 읽기 연결은 live OAuth QA가 완료될 때까지 Release 표면에서 비활성화됩니다."
        default:
            return "\(descriptor.displayName)은 현재 Release 표면에서 사용할 수 없습니다."
        }
    }
}
