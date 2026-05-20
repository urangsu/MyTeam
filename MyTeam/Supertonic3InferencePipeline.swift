import Foundation

// MARK: - Supertonic3 Inference Pipeline

/// Actor that manages the Supertonic3 ONNX inference pipeline.
/// This is a skeleton implementation that defines the pipeline structure.
/// Actual ONNX model loading and inference will be implemented in Round 249TTS.
actor Supertonic3InferencePipeline: Sendable {
    private let adapter: ONNXRuntimeAdapterProtocol

    init(adapter: ONNXRuntimeAdapterProtocol = ONNXRuntimeUnavailableAdapter()) {
        self.adapter = adapter
    }

    /// Prepares the inference pipeline by loading all required ONNX models.
    /// - Parameter modelDirectory: Directory containing the ONNX model files
    /// - Returns: Prepared pipeline with loaded model sessions
    /// - Throws: TTSProviderError if models are missing or runtime is unavailable
    func prepare(modelDirectory: URL) async throws -> PreparedSupertonic3Pipeline {
        // Step 1: Validate manifest against model directory
        // (Implementation deferred to Round 249TTS)

        // Step 2: Load each required model via adapter
        let textEncoderSession = try await loadRequiredModel(
            named: "text_encoder",
            from: modelDirectory,
            candidates: Supertonic3ModelManifest.requiredFiles[0].candidateFilenames
        )
        let durationPredictorSession = try await loadRequiredModel(
            named: "duration_predictor",
            from: modelDirectory,
            candidates: Supertonic3ModelManifest.requiredFiles[1].candidateFilenames
        )
        let vectorEstimatorSession = try await loadRequiredModel(
            named: "vector_estimator",
            from: modelDirectory,
            candidates: Supertonic3ModelManifest.requiredFiles[2].candidateFilenames
        )
        let vocoderSession = try await loadRequiredModel(
            named: "vocoder",
            from: modelDirectory,
            candidates: Supertonic3ModelManifest.requiredFiles[3].candidateFilenames
        )

        return PreparedSupertonic3Pipeline(
            textEncoder: textEncoderSession,
            durationPredictor: durationPredictorSession,
            vectorEstimator: vectorEstimatorSession,
            vocoder: vocoderSession
        )
    }

    /// Synthesizes speech from text using the prepared pipeline.
    /// - Parameters:
    ///   - text: Input text to synthesize
    ///   - preset: Voice preset (e.g., "M1", "F3")
    ///   - languageCode: Language code (e.g., "ko", "en")
    ///   - modelDirectory: Directory containing model files
    /// - Returns: TTSOutput with synthesized audio
    /// - Throws: TTSProviderError if synthesis fails
    func synthesize(
        text: String,
        preset: String,
        languageCode: String?,
        modelDirectory: URL
    ) async throws -> TTSOutput {
        // Step 1: Validate input text (non-empty, length bounds)
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw TTSProviderError.inferenceFailure("Text input is empty")
        }

        // Step 2: Prepare pipeline (load models if needed)
        let pipeline = try await prepare(modelDirectory: modelDirectory)

        // Step 3: Text normalization and tokenization
        // TODO (Round 249TTS): Implement actual tokenization based on model requirements
        let textTokens: [Int32] = [] // Placeholder

        // Step 4: Create tensor inputs
        let inputs = Supertonic3TensorInputs(
            textTokens: textTokens,
            languageCode: languageCode ?? "auto",
            voicePresetID: preset
        )

        // Step 5: Run inference pipeline stages:
        // 1. Text encoder: text_tokens → embeddings
        // 2. Duration predictor: embeddings → durations
        // 3. Vector estimator: embeddings + durations + style → vectors
        // 4. Vocoder: vectors → audio samples
        // TODO (Round 249TTS): Implement actual ONNX model execution

        // Step 6: Convert raw tensor outputs to audio buffer
        // TODO (Round 249TTS): Implement tensor→audio conversion (shape, sample rate handling)

        // Step 7: Return TTSOutput
        // Currently: throw missingRuntime since runtime is unavailable in Cloud
        throw TTSProviderError.missingRuntime
    }

    // MARK: - Private Helpers

    private func loadRequiredModel(
        named logicalName: String,
        from directory: URL,
        candidates: [String]
    ) async throws -> ONNXRuntimeSessionProtocol {
        // Try to find file by candidate names
        for candidate in candidates {
            let modelURL = directory.appendingPathComponent(candidate)
            if FileManager.default.fileExists(atPath: modelURL.path) {
                return try await adapter.loadSession(modelURL: modelURL, name: logicalName)
            }
        }

        // If no candidate found, throw error
        throw TTSProviderError.missingModel
    }
}

// MARK: - Prepared Pipeline Structure

/// Represents a fully prepared Supertonic3 inference pipeline with all models loaded.
struct PreparedSupertonic3Pipeline: Sendable {
    /// Text encoder ONNX session (converts text tokens to embeddings)
    let textEncoder: ONNXRuntimeSessionProtocol

    /// Duration predictor ONNX session (predicts phoneme durations)
    let durationPredictor: ONNXRuntimeSessionProtocol

    /// Vector estimator ONNX session (estimates acoustic vectors from embeddings and durations)
    let vectorEstimator: ONNXRuntimeSessionProtocol

    /// Vocoder ONNX session (converts acoustic vectors to audio waveform)
    let vocoder: ONNXRuntimeSessionProtocol

    init(
        textEncoder: ONNXRuntimeSessionProtocol,
        durationPredictor: ONNXRuntimeSessionProtocol,
        vectorEstimator: ONNXRuntimeSessionProtocol,
        vocoder: ONNXRuntimeSessionProtocol
    ) {
        self.textEncoder = textEncoder
        self.durationPredictor = durationPredictor
        self.vectorEstimator = vectorEstimator
        self.vocoder = vocoder
    }
}
