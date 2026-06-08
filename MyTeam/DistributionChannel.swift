import Foundation

enum DistributionChannel: String, CaseIterable, Sendable, Hashable {
    case appStore
    case direct
    case developer
}

enum FeatureGate {
    nonisolated static var current: DistributionChannel {
        switch AppReleaseProfile.current {
        case .appStore:
            return .appStore
        case .directDownload:
            return .direct
        case .debug, .powerUser:
            return .developer
        }
    }

    nonisolated static var allowsExternalSubprocess: Bool {
        current != .appStore
    }

    nonisolated static var allowsPlaywrightAutomation: Bool {
        current == .developer
    }

    nonisolated static var allowsExternalMCPServer: Bool {
        current == .developer
    }

    nonisolated static var allowsPythonRuntime: Bool {
        current == .developer
    }

    nonisolated static var allowsModelAutoDownload: Bool {
        current != .appStore
    }

    nonisolated static var allowsLocalModelOutsideContainer: Bool {
        current != .appStore
    }

    nonisolated static var allowsSupertonic3Lab: Bool {
        current == .developer
    }

    nonisolated static func allows(_ descriptor: MyTeamToolDescriptor) -> Bool {
        descriptor.supportedDistributionChannels.contains(current)
    }
}
