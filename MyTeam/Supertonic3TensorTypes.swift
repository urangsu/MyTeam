import Foundation

// Round 248TTS-A: Tensor I/O types for Supertonic3 pipeline
// Boundary: Cloud uses these stub types
// Mac local (249TTS): Will map to OrtValue tensors

struct Supertonic3TensorInputs: Sendable {
    let textTokens: [Int32]
    let languageCode: String
    let voicePresetID: String
}

struct Supertonic3TensorOutputs: Sendable {
    let values: [Float]
    let shape: [Int]
    let sampleRate: Int
}

struct Supertonic3AudioBuffer: Sendable {
    let samples: [Float]
    let sampleRate: Int

    init(samples: [Float], sampleRate: Int = 24000) {
        self.samples = samples
        self.sampleRate = sampleRate
    }
}

// Shape placeholder for future ONNX integration
// Actual shapes determined by model output in 249TTS
struct Supertonic3TensorShapeInfo: Sendable {
    let logicalName: String
    let expectedDimensions: [Int]
    let dataType: String // "float32", "int64", etc
}
