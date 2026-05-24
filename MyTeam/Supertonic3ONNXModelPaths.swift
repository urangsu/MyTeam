import Foundation

// MARK: - Supertonic3ONNXModelPaths
// Round 249TTS-SPIKE: Model path resolution for ONNX inference.
//
// Resolves paths for the 4 required ONNX model files and support files.
// Uses Supertonic3ModelLocator for the actual directory search.
// Pure value type — no FileManager calls, paths resolved lazily.
//
// Policy:
// - Model files live outside app bundle (~/.cache/supertonic3/onnx/)
// - No auto-download, no app-bundle inclusion
// - spike scope only — not exposed on production surfaces

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
        textEncoderURL       = modelDirectory.appendingPathComponent("text_encoder.onnx")
        durationPredictorURL = modelDirectory.appendingPathComponent("duration_predictor.onnx")
        vectorEstimatorURL   = modelDirectory.appendingPathComponent("vector_estimator.onnx")
        vocoderURL           = modelDirectory.appendingPathComponent("vocoder.onnx")
        unicodeIndexerURL    = modelDirectory.appendingPathComponent("unicode_indexer.json")
        ttsConfigURL         = modelDirectory.appendingPathComponent("tts.json")
        // voice_styles is a sibling directory to onnx/
        voiceStylesDirectoryURL = modelDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("voice_styles")
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
        Supertonic3ONNXModelPaths(modelDirectory: Supertonic3TTSConfig.modelDirectoryURL)
    }

    /// Voice style JSON file URL for a given preset name (e.g., "F1", "M3").
    nonisolated func voiceStyleURL(preset: String) -> URL {
        voiceStylesDirectoryURL.appendingPathComponent("\(preset).json")
    }
}
