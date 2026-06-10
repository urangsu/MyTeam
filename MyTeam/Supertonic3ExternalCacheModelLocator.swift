import Foundation

enum Supertonic3ExternalCacheModelLocator {
    nonisolated static func modelDirectoryURL() throws -> URL {
        guard FeatureGate.current == .developer else {
            throw Supertonic3ModelError.externalCacheNotAllowed
        }
        return Supertonic3TTSConfig.modelDirectoryURL
    }

    nonisolated static func voiceStylesDirectoryURL() throws -> URL {
        guard FeatureGate.current == .developer else {
            throw Supertonic3ModelError.externalCacheNotAllowed
        }
        return Supertonic3TTSConfig.voiceStylesDirectoryURL
    }

    nonisolated static func paths() throws -> Supertonic3ONNXModelPaths {
        Supertonic3ONNXModelPaths(
            modelDirectory: try modelDirectoryURL(),
            voiceStylesDirectory: try voiceStylesDirectoryURL()
        )
    }
}
