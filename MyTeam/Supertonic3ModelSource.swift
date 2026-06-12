import Foundation

enum Supertonic3ModelSource: String, Sendable {
    case bundled
    case appSupport
    case externalCacheDeveloperOnly
}

enum Supertonic3ModelError: LocalizedError, Sendable {
    case bundledResourceMissing(String)
    case requiredFilesMissing([String])
    case externalCacheNotAllowed
    case appSupportUnavailable

    var errorDescription: String? {
        switch self {
        case .bundledResourceMissing(let name):
            return "Bundled Supertonic3 resource is missing: \(name)"
        case .requiredFilesMissing(let names):
            return "Supertonic3 required files are missing: \(names.joined(separator: ", "))"
        case .externalCacheNotAllowed:
            return "External Supertonic3 cache is allowed only in Developer builds."
        case .appSupportUnavailable:
            return "Application Support Supertonic3 model directory is unavailable."
        }
    }
}

enum Supertonic3ModelSourcePolicy {
    nonisolated static var preferredSource: Supertonic3ModelSource {
        switch FeatureGate.current {
        case .appStore:
            return .bundled
        case .direct:
            return .bundled
        case .developer:
            return .externalCacheDeveloperOnly
        }
    }
}

enum Supertonic3DistributionGate {
    nonisolated static var isRuntimeAllowed: Bool {
        switch FeatureGate.current {
        case .appStore:
            return Supertonic3ReleaseGate.isAppStoreApproved
        case .direct, .developer:
            return true
        }
    }

    nonisolated static var blockedReason: String? {
        guard !isRuntimeAllowed else { return nil }
        return "Supertonic3 App Store release gate is not approved yet."
    }
}

enum Supertonic3ModelAvailability {
    nonisolated static var current: Supertonic3ModelLocator.ModelCheckResult {
        Supertonic3ModelLocator.checkModel()
    }

    nonisolated static var isReady: Bool {
        current.isAvailable
    }
}

enum Supertonic3AppSupportModelLocator {
    nonisolated static func modelDirectoryURL() throws -> URL {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw Supertonic3ModelError.appSupportUnavailable
        }
        return base
            .appendingPathComponent("MyTeam", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("Supertonic3", isDirectory: true)
            .appendingPathComponent("onnx", isDirectory: true)
    }

    nonisolated static func voiceStylesDirectoryURL() throws -> URL {
        try modelDirectoryURL()
            .deletingLastPathComponent()
            .appendingPathComponent("voice_styles", isDirectory: true)
    }

    nonisolated static func paths() throws -> Supertonic3ONNXModelPaths {
        Supertonic3ONNXModelPaths(modelDirectory: try modelDirectoryURL())
    }
}
