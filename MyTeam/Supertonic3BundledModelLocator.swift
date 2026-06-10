import Foundation

enum Supertonic3BundledModelLocator {
    nonisolated private static let bundleDirectoryName = "Supertonic3"
    nonisolated private static let onnxDirectoryName = "onnx"
    nonisolated private static let voiceStylesDirectoryName = "voice_styles"

    nonisolated static func modelDirectoryURL() throws -> URL {
        guard let base = Bundle.main.resourceURL else {
            throw Supertonic3ModelError.bundledResourceMissing("Resources")
        }
        return base
            .appendingPathComponent(bundleDirectoryName, isDirectory: true)
            .appendingPathComponent(onnxDirectoryName, isDirectory: true)
    }

    nonisolated static func voiceStylesDirectoryURL() throws -> URL {
        guard let base = Bundle.main.resourceURL else {
            throw Supertonic3ModelError.bundledResourceMissing("Resources")
        }
        return base
            .appendingPathComponent(bundleDirectoryName, isDirectory: true)
            .appendingPathComponent(voiceStylesDirectoryName, isDirectory: true)
    }

    nonisolated static func paths() throws -> Supertonic3ONNXModelPaths {
        Supertonic3ONNXModelPaths(
            modelDirectory: try modelDirectoryURL(),
            voiceStylesDirectory: try voiceStylesDirectoryURL()
        )
    }

    nonisolated static func validateRequiredFiles() throws {
        let modelDirectory = try modelDirectoryURL()
        let voiceStylesDirectory = try voiceStylesDirectoryURL()
        var missing: [String] = []

        for file in Supertonic3TTSConfig.requiredModelFiles {
            let url = modelDirectory.appendingPathComponent(file)
            if !FileManager.default.fileExists(atPath: url.path) {
                missing.append("onnx/\(file)")
            }
        }

        for preset in Supertonic3TTSConfig.availableVoicePresets {
            let url = voiceStylesDirectory.appendingPathComponent("\(preset).json")
            if !FileManager.default.fileExists(atPath: url.path) {
                missing.append("voice_styles/\(preset).json")
            }
        }

        if !missing.isEmpty {
            throw Supertonic3ModelError.requiredFilesMissing(missing)
        }
    }
}
