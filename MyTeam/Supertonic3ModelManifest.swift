import Foundation

// Round 248TTS-A: Manifest-driven model discovery for distribution flexibility
// Supports multiple candidate filenames per logical component
// No hardcoded paths in code

struct Supertonic3ModelManifest {

    struct RequiredModelFile: Sendable {
        let logicalName: String
        let candidateFilenames: [String]
        let required: Bool
    }

    // Primary required ONNX models (4 files ~398 MB total)
    static let requiredFiles: [RequiredModelFile] = [
        RequiredModelFile(
            logicalName: "text_encoder",
            candidateFilenames: ["text_encoder.onnx", "encoder.onnx", "text_encoder_model.onnx"],
            required: true
        ),
        RequiredModelFile(
            logicalName: "duration_predictor",
            candidateFilenames: ["duration_predictor.onnx", "duration.onnx", "duration_model.onnx"],
            required: true
        ),
        RequiredModelFile(
            logicalName: "vector_estimator",
            candidateFilenames: ["vector_estimator.onnx", "estimator.onnx", "vector_model.onnx"],
            required: true
        ),
        RequiredModelFile(
            logicalName: "vocoder",
            candidateFilenames: ["vocoder.onnx", "vocoder_model.onnx"],
            required: true
        )
    ]

    // Optional support files
    static let optionalFiles: [RequiredModelFile] = [
        RequiredModelFile(
            logicalName: "voice_styles",
            candidateFilenames: ["voice_styles.json", "styles.json", "voice_presets.json"],
            required: false
        ),
        RequiredModelFile(
            logicalName: "config",
            candidateFilenames: ["config.json", "model_config.json"],
            required: false
        ),
        RequiredModelFile(
            logicalName: "tokenizer",
            candidateFilenames: ["tokenizer.json", "vocab.json"],
            required: false
        )
    ]

    // Model metadata (informational, not enforced in Cloud)
    static let metadata = [
        "source": "Hugging Face / MIT Sample Implementation",
        "framework": "ONNX",
        "languages": 31,
        "license": "OpenRAIL-M + MIT",
        "sampleRate": 24000,
        "architectureSize": "99M",
        "note": "Cloud: skeleton only. Mac local: ONNX Runtime inference in 249TTS."
    ]

    /// Locates model file by trying candidates in order
    static func findModelFile(
        logicalName: String,
        in directory: URL
    ) -> URL? {
        let allFiles = requiredFiles + optionalFiles
        guard let definition = allFiles.first(where: { $0.logicalName == logicalName }) else {
            return nil
        }

        for candidate in definition.candidateFilenames {
            let path = directory.appendingPathComponent(candidate)
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }

        return nil
    }
}
