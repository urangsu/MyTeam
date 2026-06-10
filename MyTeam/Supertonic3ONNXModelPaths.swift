import Foundation

// MARK: - Supertonic3ONNXModelPaths
// Round 249TTS-SPIKE: Model path resolution for ONNX inference.
//
// Resolves paths for the 4 required ONNX model files and support files.
// Uses Supertonic3ModelLocator for the actual directory search.
// Pure value type — no FileManager calls, paths resolved lazily.
//
// Policy:
// - App Store / Direct routes through the bundled model locator.
// - Developer builds may use the external ~/.cache path for local iteration.
// - No auto-download. Missing model files are unavailable, not fallback success.

struct Supertonic3ONNXModelPaths: Sendable {

    // MARK: - Resolved URLs

    let textEncoderURL: URL
    let durationPredictorURL: URL
    let vectorEstimatorURL: URL
    let vocoderURL: URL
    let unicodeIndexerURL: URL
    let ttsConfigURL: URL
    let voiceStylesDirectoryURL: URL

    // MARK: - Init from directory

    nonisolated init(modelDirectory: URL) {
        self.init(
            modelDirectory: modelDirectory,
            voiceStylesDirectory: modelDirectory
                .deletingLastPathComponent()
                .appendingPathComponent("voice_styles", isDirectory: true)
        )
    }

    nonisolated init(modelDirectory: URL, voiceStylesDirectory: URL) {
        textEncoderURL       = modelDirectory.appendingPathComponent("text_encoder.onnx")
        durationPredictorURL = modelDirectory.appendingPathComponent("duration_predictor.onnx")
        vectorEstimatorURL   = modelDirectory.appendingPathComponent("vector_estimator.onnx")
        vocoderURL           = modelDirectory.appendingPathComponent("vocoder.onnx")
        unicodeIndexerURL    = modelDirectory.appendingPathComponent("unicode_indexer.json")
        ttsConfigURL         = modelDirectory.appendingPathComponent("tts.json")
        voiceStylesDirectoryURL = voiceStylesDirectory
    }

    // MARK: - Validation

    /// Returns true if all required ONNX model files exist on disk.
    nonisolated var allModelsPresent: Bool {
        let required = [textEncoderURL, durationPredictorURL, vectorEstimatorURL, vocoderURL]
        return required.allSatisfy { url in
            FileManager.default.fileExists(atPath: url.path)
        }
    }

    /// Missing file names (for error reporting).
    nonisolated var missingModelNames: [String] {
        let named: [(URL, String)] = [
            (textEncoderURL, "text_encoder.onnx"),
            (durationPredictorURL, "duration_predictor.onnx"),
            (vectorEstimatorURL, "vector_estimator.onnx"),
            (vocoderURL, "vocoder.onnx")
        ]
        return named
            .filter { !FileManager.default.fileExists(atPath: $0.0.path) }
            .map { $0.1 }
    }

    // MARK: - Factory

    /// Creates paths from the default Supertonic3 model directory.
    nonisolated static func defaultPaths() -> Supertonic3ONNXModelPaths {
        switch Supertonic3ModelSourcePolicy.preferredSource {
        case .bundled:
            if let paths = try? Supertonic3BundledModelLocator.paths() {
                return paths
            }
            return Supertonic3ONNXModelPaths(
                modelDirectory: URL(fileURLWithPath: "/__missing_bundled_supertonic3__/onnx", isDirectory: true),
                voiceStylesDirectory: URL(fileURLWithPath: "/__missing_bundled_supertonic3__/voice_styles", isDirectory: true)
            )
        case .appSupport:
            if let paths = try? Supertonic3AppSupportModelLocator.paths() {
                return paths
            }
            return Supertonic3ONNXModelPaths(
                modelDirectory: URL(fileURLWithPath: "/__missing_app_support_supertonic3__/onnx", isDirectory: true),
                voiceStylesDirectory: URL(fileURLWithPath: "/__missing_app_support_supertonic3__/voice_styles", isDirectory: true)
            )
        case .externalCacheDeveloperOnly:
            if let paths = try? Supertonic3ExternalCacheModelLocator.paths() {
                return paths
            }
            return Supertonic3ONNXModelPaths(
                modelDirectory: URL(fileURLWithPath: "/__external_cache_not_allowed__/onnx", isDirectory: true),
                voiceStylesDirectory: URL(fileURLWithPath: "/__external_cache_not_allowed__/voice_styles", isDirectory: true)
            )
        }
    }

    /// Voice style JSON file URL for a given preset name (e.g., "F1", "M3").
    nonisolated func voiceStyleURL(preset: String) -> URL {
        voiceStylesDirectoryURL.appendingPathComponent("\(preset).json")
    }
}
