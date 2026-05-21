import Foundation
import onnxruntime_objc

// MARK: - Supertonic3ONNXRunner
// Round 249TTS-SPIKE: Full Supertonic3 ONNX inference pipeline in Swift.
//
// 4-stage pipeline (mirrors Python Supertonic.__call__):
//   1. Duration predictor  → character durations
//   2. Text encoder        → text embeddings
//   3. Vector estimator    → flow-matching ODE (N steps, default 8)
//   4. Vocoder             → audio waveform
//
// Configuration from tts.json:
//   sample_rate=44100, base_chunk_size=512, chunk_compress_factor=6, ldim=24
//
// Policy:
//   - Spike scope only — not exposed on production surfaces
//   - No auto-init on launch — user triggers synthesis explicitly from TTSLabView
//   - All sessions created per-synthesis call (no persistent state across calls)
//   - No Apple TTS anywhere in this file

// MARK: - Config Constants

private enum S3Config {
    static let sampleRate: Int = 44100
    static let baseChunkSize: Int = 512          // AE latent frames per audio chunk
    static let chunkCompressFactor: Int = 6       // TTS latent frames compression
    static let latentDim: Int = 24                // ldim
    static let totalStepDefault: Int = 8          // flow-matching ODE steps
}

// MARK: - Result Types

struct Supertonic3SynthesisResult: Sendable {
    let wavSamples: [Float]       // raw PCM Float32, shape [N]
    let sampleRate: Int           // always 44100
    let durationSec: Double       // total audio duration in seconds
    let elapsedMs: Double         // wall-clock inference time in milliseconds
    let realtimeFactor: Double    // elapsedMs / (durationSec * 1000) — lower is faster
    let presetUsed: String
    let textLength: Int           // token count after tokenization
    let latentFrameCount: Int     // L — total latent frames
}

// MARK: - Runner

/// Runs a full Supertonic3 synthesis pass using on-disk ONNX models.
/// Stateless — creates new OrtSessions per call.
/// Spike-only: this actor is intentionally NOT registered in SpeechManager or any production surface.
actor Supertonic3ONNXRunner {

    static let shared = Supertonic3ONNXRunner()
    private init() {}

    // MARK: - Main Synthesis

    /// Full synthesis pipeline.
    /// - Parameters:
    ///   - text: Input text
    ///   - preset: Voice preset ("F1".."M5")
    ///   - lang: Language code ("ko", "en", "ja", "na", etc.) or nil for v1
    ///   - totalSteps: Flow-matching ODE steps (default 8; range 4–12)
    ///   - paths: Resolved model paths
    /// - Returns: `Supertonic3SynthesisResult` with PCM samples at 44100 Hz
    func synthesize(
        text: String,
        preset: String,
        lang: String?,
        totalSteps: Int = S3Config.totalStepDefault,
        paths: Supertonic3ONNXModelPaths
    ) async throws -> Supertonic3SynthesisResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        // --- 1. Validate paths ---
        let missing = paths.missingModelNames
        if !missing.isEmpty {
            throw Supertonic3ONNXRunnerError.missingModelFiles(missing)
        }

        // --- 2. Load unicode indexer ---
        let indexer = try Supertonic3UnicodeIndexer.load(from: paths.unicodeIndexerURL)

        // --- 3. Tokenize text ---
        let (textIds, _, seqLen) = try indexer.encode(text: text, lang: lang)
        guard seqLen > 0 else {
            throw Supertonic3ONNXRunnerError.emptyTokenSequence
        }

        // --- 4. Load voice style ---
        let styleURL = paths.voiceStyleURL(preset: preset)
        let style = try Supertonic3VoiceStyle.load(from: styleURL, preset: preset)

        // --- 5. Create ONNX environment ---
        let env = try ORTEnvironment(loggingLevel: .warning)

        // --- 6. Stage 1: Duration predictor ---
        // text_ids: [1, T] int64
        // style_dp: [1, 8, 16] float32
        // text_mask: [1, 1, T] float32
        // → dur_onnx: [1, T] float32
        let durOnnx: [Float]
        let textEmbOnnx: [Float]
        let textEmbShape: [Int]
        let latentL: Int
        let latentDim = S3Config.latentDim * S3Config.chunkCompressFactor  // 144

        do {
            let dpSession = try ORTSession(env: env, modelPath: paths.durationPredictorURL.path, sessionOptions: nil)

            let textIdsTensor    = try makeTensor(int64: textIds, shape: [1, seqLen])
            let textMaskTensor1T = try makeTensor(float32: [Float](repeating: 1.0, count: seqLen), shape: [1, 1, seqLen])
            let styleDPTensor    = try makeTensor(float32: style.styleDP, shape: style.styleDPShape)

            let dpInputs: [String: ORTValue] = [
                "text_ids":  textIdsTensor,
                "style_dp":  styleDPTensor,
                "text_mask": textMaskTensor1T
            ]
            let dpOutputs = try dpSession.run(withInputs: dpInputs, outputNames: ["dur_onnx"], runOptions: nil)
            guard let durValue = dpOutputs["dur_onnx"] else {
                throw Supertonic3ONNXRunnerError.missingOutput("dur_onnx")
            }
            durOnnx = try floatArray(from: durValue)
        }

        // --- 7. Compute latent length from durations ---
        // Python: wav_len_max = duration.max() * sample_rate
        //         wav_lengths = (duration * sample_rate).astype(int64)
        //         chunk_size = base_chunk_size * chunk_compress_factor
        //         latent_len = ceil(wav_len_max + chunk_size - 1) / chunk_size)
        let wavLengths = durOnnx.map { Int64(Double($0) * Double(S3Config.sampleRate)) }
        let chunkSize = S3Config.baseChunkSize * S3Config.chunkCompressFactor  // 3072
        let wavLenMax = wavLengths.max() ?? 1
        latentL = Int((Double(wavLenMax) + Double(chunkSize) - 1.0) / Double(chunkSize))
        let latentMaskFlat = makeLatentMask(wavLengths: wavLengths, chunkSize: chunkSize, latentLen: latentL)

        // --- 8. Stage 2: Text encoder ---
        // text_ids: [1, T] int64
        // style_ttl: [1, 50, 256] float32
        // text_mask: [1, 1, T] float32
        // → text_emb: [1, T, 256] float32
        do {
            let encSession = try ORTSession(env: env, modelPath: paths.textEncoderURL.path, sessionOptions: nil)

            let textIdsTensor    = try makeTensor(int64: textIds, shape: [1, seqLen])
            let textMaskTensor1T = try makeTensor(float32: [Float](repeating: 1.0, count: seqLen), shape: [1, 1, seqLen])
            let styleTTLTensor   = try makeTensor(float32: style.styleTTL, shape: style.styleTTLShape)

            let encInputs: [String: ORTValue] = [
                "text_ids":  textIdsTensor,
                "style_ttl": styleTTLTensor,
                "text_mask": textMaskTensor1T
            ]
            let encOutputs = try encSession.run(withInputs: encInputs, outputNames: ["text_emb"], runOptions: nil)
            guard let embValue = encOutputs["text_emb"] else {
                throw Supertonic3ONNXRunnerError.missingOutput("text_emb")
            }
            textEmbOnnx = try floatArray(from: embValue)
            let embInfo = try embValue.tensorTypeAndShapeInfo()
            textEmbShape = embInfo.shape as! [Int]
        }

        // --- 9. Stage 3: Vector estimator (flow matching) ---
        // Initial noisy latent: [1, latentDim, L] Gaussian noise, masked
        var xt = gaussianNoise(count: 1 * latentDim * latentL)

        // Apply latent mask to initial noise
        // latent_mask: [1, 1, L] → replicate to [1, latentDim, L]
        for frameIdx in 0..<latentL {
            let maskVal = latentMaskFlat[frameIdx]
            for dimIdx in 0..<latentDim {
                let idx = dimIdx * latentL + frameIdx
                xt[idx] *= maskVal
            }
        }

        let veSession = try ORTSession(env: env, modelPath: paths.vectorEstimatorURL.path, sessionOptions: nil)
        let totalStepF = Float(totalSteps)
        let styleTTLTensor = try makeTensor(float32: style.styleTTL, shape: style.styleTTLShape)
        let textMaskTensor1T = try makeTensor(float32: [Float](repeating: 1.0, count: seqLen), shape: [1, 1, seqLen])
        let latentMaskTensor = try makeTensor(float32: latentMaskFlat, shape: [1, 1, latentL])
        let textEmbTensor = try makeTensor(float32: textEmbOnnx, shape: textEmbShape)
        let totalStepTensor = try makeTensor(float32: [totalStepF], shape: [1])

        for step in 0..<totalSteps {
            let currentStepTensor = try makeTensor(float32: [Float(step)], shape: [1])
            let xtTensor = try makeTensor(float32: xt, shape: [1, latentDim, latentL])

            let veInputs: [String: ORTValue] = [
                "noisy_latent":  xtTensor,
                "text_emb":      textEmbTensor,
                "style_ttl":     styleTTLTensor,
                "text_mask":     textMaskTensor1T,
                "latent_mask":   latentMaskTensor,
                "current_step":  currentStepTensor,
                "total_step":    totalStepTensor
            ]
            let veOutputs = try veSession.run(withInputs: veInputs, outputNames: ["xt"], runOptions: nil)
            guard let xtValue = veOutputs["xt"] else {
                throw Supertonic3ONNXRunnerError.missingOutput("xt (step \(step))")
            }
            xt = try floatArray(from: xtValue)
        }

        // --- 10. Stage 4: Vocoder ---
        // latent: [1, latentDim, L] float32 → wav: [1, N] float32
        let vocSession = try ORTSession(env: env, modelPath: paths.vocoderURL.path, sessionOptions: nil)
        let latentTensor = try makeTensor(float32: xt, shape: [1, latentDim, latentL])
        let vocOutputs = try vocSession.run(withInputs: ["latent": latentTensor], outputNames: ["wav"], runOptions: nil)
        guard let wavValue = vocOutputs["wav"] else {
            throw Supertonic3ONNXRunnerError.missingOutput("wav")
        }
        let wavSamples = try floatArray(from: wavValue)

        // --- 11. Compute metrics ---
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        let durationSec = Double(wavSamples.count) / Double(S3Config.sampleRate)
        let rtf = durationSec > 0 ? elapsedMs / (durationSec * 1000.0) : 0.0

        return Supertonic3SynthesisResult(
            wavSamples: wavSamples,
            sampleRate: S3Config.sampleRate,
            durationSec: durationSec,
            elapsedMs: elapsedMs,
            realtimeFactor: rtf,
            presetUsed: preset,
            textLength: seqLen,
            latentFrameCount: latentL
        )
    }

    // MARK: - Private: Tensor helpers

    /// Create an Int64 ONNX tensor.
    private func makeTensor(int64: [Int64], shape: [Int]) throws -> ORTValue {
        var mutable = int64
        let data = NSMutableData(bytes: &mutable, length: mutable.count * MemoryLayout<Int64>.stride)
        let nsShape = shape.map { NSNumber(value: $0) }
        return try ORTValue(tensorData: data, elementType: .int64, shape: nsShape)
    }

    /// Create a Float32 ONNX tensor.
    private func makeTensor(float32: [Float], shape: [Int]) throws -> ORTValue {
        var mutable = float32
        let data = NSMutableData(bytes: &mutable, length: mutable.count * MemoryLayout<Float>.stride)
        let nsShape = shape.map { NSNumber(value: $0) }
        return try ORTValue(tensorData: data, elementType: .float, shape: nsShape)
    }

    /// Extract [Float] from an ORTValue tensor.
    private func floatArray(from value: ORTValue) throws -> [Float] {
        let data = try value.tensorData() as Data
        return data.withUnsafeBytes { ptr -> [Float] in
            let buffer = ptr.bindMemory(to: Float.self)
            return Array(buffer)
        }
    }

    // MARK: - Private: Latent mask

    /// Python equivalent of get_latent_mask → length_to_mask.
    /// Returns flat [Float] of shape [1, L] (flattened from [1, 1, L]).
    /// Value = 1.0 if frameIdx < latent_length_for_sequence, else 0.0.
    private func makeLatentMask(wavLengths: [Int64], chunkSize: Int, latentLen: Int) -> [Float] {
        // Python: latent_lengths = (wav_lengths + latent_size - 1) // latent_size
        // length_to_mask returns [B, 1, maxLen]
        // For batch_size=1, we flatten to [latentLen]
        let wavLen = wavLengths.first ?? 0
        let latentLengthForSeq = (Int(wavLen) + chunkSize - 1) / chunkSize
        return (0..<latentLen).map { frameIdx in
            frameIdx < latentLengthForSeq ? 1.0 : 0.0
        }
    }

    // MARK: - Private: Gaussian noise (Box-Muller transform)

    /// Generate Gaussian noise using Box-Muller transform.
    /// Swift's Float.random() is uniform [0,1) — Box-Muller converts to N(0,1).
    private func gaussianNoise(count: Int) -> [Float] {
        var result = [Float](repeating: 0.0, count: count)
        var i = 0
        while i < count {
            // Box-Muller: two uniform samples → two Gaussian samples
            let u1 = Float.random(in: Float.leastNormalMagnitude...1.0)
            let u2 = Float.random(in: 0.0...1.0)
            let mag = Foundation.sqrt(-2.0 * Foundation.log(u1))
            let z0 = mag * Foundation.cos(2.0 * Float.pi * u2)
            let z1 = mag * Foundation.sin(2.0 * Float.pi * u2)
            result[i] = z0
            if i + 1 < count {
                result[i + 1] = z1
            }
            i += 2
        }
        return result
    }
}

// MARK: - Errors

enum Supertonic3ONNXRunnerError: Error, Sendable, LocalizedError {
    case missingModelFiles([String])
    case emptyTokenSequence
    case missingOutput(String)
    case inferenceFailure(String)

    var errorDescription: String? {
        switch self {
        case .missingModelFiles(let files):
            return "Missing ONNX model files: \(files.joined(separator: ", "))"
        case .emptyTokenSequence:
            return "Text produced empty token sequence after tokenization"
        case .missingOutput(let name):
            return "ONNX session did not produce expected output: \(name)"
        case .inferenceFailure(let msg):
            return "ONNX inference failure: \(msg)"
        }
    }
}
