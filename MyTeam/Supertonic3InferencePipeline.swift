import Foundation

// MARK: - Supertonic3 Inference Pipeline

/// Actor that manages the Supertonic3 ONNX inference pipeline.
/// Round 247TTS: Cloud skeleton — all methods throw .missingRuntime.
/// Round 249TTS: Actual ONNX model loading and inference (Mac local, SPM 의존성 추가 후).
actor Supertonic3InferencePipeline: Sendable {

    // MARK: - Prepare

    /// Prepares the inference pipeline by loading all required ONNX models.
    /// - Parameter modelDirectory: Directory containing the ONNX model files
    /// - Returns: Prepared pipeline with loaded model sessions
    /// - Throws: TTSProviderError.missingRuntime (Cloud), or model errors (Mac 249TTS)
    func prepare(modelDirectory: URL) async throws -> PreparedSupertonic3Pipeline {
        // Cloud skeleton: ONNX Runtime not available.
        // 249TTS(Mac): validate manifest, load 4 ONNX sessions via adapter.
        throw TTSProviderError.missingRuntime
    }

    // MARK: - Synthesize

    /// Synthesizes speech from text using the prepared pipeline.
    /// - Parameters:
    ///   - text: Input text to synthesize
    ///   - preset: Voice preset (e.g., "M1", "F3")
    ///   - languageCode: Language code (e.g., "ko", "en")
    ///   - modelDirectory: Directory containing model files
    /// - Returns: TTSOutput with synthesized audio
    /// - Throws: TTSProviderError.missingRuntime (Cloud), or inference errors (Mac 249TTS)
    func synthesize(
        text: String,
        preset: String,
        languageCode: String?,
        modelDirectory: URL
    ) async throws -> TTSOutput {
        // Cloud skeleton: ONNX Runtime not available. Always throws.
        // 249TTS(Mac): tokenize text, run 4-stage pipeline, convert to audio buffer.
        throw TTSProviderError.missingRuntime
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
