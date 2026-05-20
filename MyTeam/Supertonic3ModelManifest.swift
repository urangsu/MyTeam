import Foundation

// MARK: - Supertonic3 Model Manifest

struct Supertonic3ModelManifest: Sendable {
    /// Represents a required or optional model file with candidate filenames.
    struct RequiredModelFile: Sendable {
        /// Logical name of the model component (e.g., "text_encoder", "vocoder")
        let logicalName: String

        /// Candidate filenames for this component (e.g., ["text_encoder.onnx", "encoder.onnx"])
        /// Multiple candidates allow flexibility in model naming conventions.
        let candidateFilenames: [String]

        /// Whether this file must be present for inference to proceed
        let required: Bool

        init(logicalName: String, candidateFilenames: [String], required: Bool) {
            self.logicalName = logicalName
            self.candidateFilenames = candidateFilenames
            self.required = required
        }
    }

    /// Required ONNX model files for Supertonic3 inference pipeline.
    /// NOTE: These filenames are candidates and may change based on actual model distribution in Round 249TTS.
    static let requiredFiles: [RequiredModelFile] = [
        RequiredModelFile(
            logicalName: "text_encoder",
            candidateFilenames: ["text_encoder.onnx", "encoder.onnx"],
            required: true
        ),
        RequiredModelFile(
            logicalName: "duration_predictor",
            candidateFilenames: ["duration_predictor.onnx", "duration.onnx"],
            required: true
        ),
        RequiredModelFile(
            logicalName: "vector_estimator",
            candidateFilenames: ["vector_estimator.onnx", "estimator.onnx"],
            required: true
        ),
        RequiredModelFile(
            logicalName: "vocoder",
            candidateFilenames: ["vocoder.onnx"],
            required: true
        )
    ]

    /// Optional configuration/metadata files for Supertonic3.
    /// These files may enhance functionality but are not required for basic inference.
    static let optionalFiles: [RequiredModelFile] = [
        RequiredModelFile(
            logicalName: "voice_styles",
            candidateFilenames: ["voice_styles.json", "styles.json"],
            required: false
        ),
        RequiredModelFile(
            logicalName: "config",
            candidateFilenames: ["config.json"],
            required: false
        ),
        RequiredModelFile(
            logicalName: "tokenizer",
            candidateFilenames: ["tokenizer.json"],
            required: false
        )
    ]
}
