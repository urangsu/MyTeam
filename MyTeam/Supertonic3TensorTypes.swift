import Foundation

// MARK: - Tensor Input/Output Types for Supertonic3 Inference

/// Placeholder tensor input structure for Supertonic3 inference.
/// NOTE: This structure is temporary and will be refined based on actual ONNX model signatures in Round 249TTS.
/// Do NOT assume this matches production model tensor specifications.
struct Supertonic3TensorInputs: Sendable {
    /// Tokenized text input (Int32 array)
    let textTokens: [Int32]

    /// Language code (e.g., "ko", "en", "ja")
    let languageCode: String

    /// Voice preset ID (e.g., "M1", "F3")
    let voicePresetID: String

    init(textTokens: [Int32], languageCode: String, voicePresetID: String) {
        self.textTokens = textTokens
        self.languageCode = languageCode
        self.voicePresetID = voicePresetID
    }
}

/// Placeholder tensor output structure from Supertonic3 inference.
/// NOTE: This structure is temporary and will be refined based on actual ONNX model output in Round 249TTS.
/// Do NOT assume this matches production model tensor format.
struct Supertonic3TensorOutputs: Sendable {
    /// Audio tensor values (typically Float32)
    let values: [Float]

    /// Tensor shape (e.g., [1, num_samples])
    let shape: [Int]

    /// Sample rate of output audio
    let sampleRate: Int

    init(values: [Float], shape: [Int], sampleRate: Int) {
        self.values = values
        self.shape = shape
        self.sampleRate = sampleRate
    }
}

/// Audio buffer representation after ONNX inference and conversion.
struct Supertonic3AudioBuffer: Sendable {
    /// Normalized audio samples (Float32, typically -1.0 to 1.0)
    let samples: [Float]

    /// Sample rate of audio (e.g., 44100, 24000)
    let sampleRate: Int

    init(samples: [Float], sampleRate: Int) {
        self.samples = samples
        self.sampleRate = sampleRate
    }
}
