import Foundation
import OnnxRuntimeBindings

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
// Uses OnnxRuntimeBindings (ObjC API from onnxruntime-swift-package-manager).
// Import: `import OnnxRuntimeBindings` — module name from the SPM target.
//
// Policy:
//   - Spike scope only — not exposed on production surfaces
//   - No auto-init on launch — user triggers synthesis explicitly from TTSLabView
//   - All sessions created per-synthesis call (no persistent state across calls)
//   - No Apple TTS anywhere in this file

// MARK: - Config Constants

// S3Config: 순수 Int 상수 — Sendable value type이므로 actor isolation 불필요.
// 아래 main-actor-isolated 경고는 Swift 5 호환 모드에서 "Swift 6 future error" 수준의 경고임.
// Supertonic3ONNXModelPaths.missingModelNames / UnicodeIndexer.load / VoiceStyle.load 등
// 호출 대상이 @MainActor인 경우 발생; Spike 전용 파일이므로 현행 유지.
private enum S3Config {
    static let sampleRate: Int          = 44100
    static let baseChunkSize: Int       = 512
    static let chunkCompressFactor: Int = 6
    static let ldim: Int                = 24
    static let totalStepDefault: Int    = 8
    // Derived:
    static let chunkSize: Int  = 512 * 6   // baseChunkSize * chunkCompressFactor = 3072
    static let latentDim: Int  = 24  * 6   // ldim * chunkCompressFactor = 144
}

// MARK: - Result Types

struct Supertonic3SynthesisResult: Sendable {
    let wavSamples: [Float]
    let sampleRate: Int
    let durationSec: Double
    let elapsedMs: Double
    let realtimeFactor: Double
    let presetUsed: String
    let textLength: Int
    let latentFrameCount: Int
}

// MARK: - Runner

/// Runs a full Supertonic3 synthesis pass using on-disk ONNX models.
/// Stateless — creates new ORTSessions per call.
/// Spike-only: this actor is intentionally NOT registered in SpeechManager or any production surface.
actor Supertonic3ONNXRunner {

    static let shared = Supertonic3ONNXRunner()
    private init() {}

    // MARK: - Main Synthesis

    func synthesize(
        text: String,
        preset: String,
        lang: String?,
        totalSteps: Int = 8,   // S3Config.totalStepDefault — literal avoids @MainActor default-isolation inference
        speed: Float = 1.05,
        paths: Supertonic3ONNXModelPaths
    ) async throws -> Supertonic3SynthesisResult {
        let t0 = CFAbsoluteTimeGetCurrent()
        // Local constants shadow S3Config to avoid @MainActor inference from default-isolation=MainActor
        let sampleRate: Int = 44100
        let chunkSize: Int  = 3072  // 512 * 6
        let latentDim: Int  = 144   // 24 * 6

        // 1. Validate paths
        let missing = paths.missingModelNames
        guard missing.isEmpty else { throw Supertonic3ONNXRunnerError.missingModelFiles(missing) }

        // 2. Tokenize
        let indexer = try Supertonic3UnicodeIndexer.load(from: paths.unicodeIndexerURL)
        let (textIds, _, seqLen) = try indexer.encode(text: text, lang: lang)
        guard seqLen > 0 else { throw Supertonic3ONNXRunnerError.emptyTokenSequence }

        // 3. Voice style
        let style = try Supertonic3VoiceStyle.load(
            from: paths.voiceStyleURL(preset: preset), preset: preset)

        // 4. ORTEnv — shared across all sessions in this synthesis call
        let env = try ORTEnv(loggingLevel: .warning)

        let textMask1T = [Float](repeating: 1.0, count: seqLen)

        // Stage 1: Duration predictor
        // text_ids:[1,T] int64, style_dp:[1,8,16] f32, text_mask:[1,1,T] f32 → duration:[1,T] f32
        let durOnnx: [Float]
        do {
            let sess = try ortSession(env: env, modelPath: paths.durationPredictorURL.path)
            let inputs: [String: ORTValue] = [
                "text_ids":  try makeTensorI64(textIds, shape: [1, seqLen]),
                "style_dp":  try makeTensorF32(style.styleDP, shape: style.styleDPShape),
                "text_mask": try makeTensorF32(textMask1T, shape: [1, 1, seqLen])
            ]
            let outs = try ortRun(sess, inputs: inputs, outputNames: ["duration"])
            durOnnx = try floatArray(from: outs["duration"])
        }

        // Compute latent length from durations
        // Python applies speed=1.05 default: dur_onnx / speed (higher speed → shorter duration)
        // Round 260B: official Supertonic3 speed range 0.70~2.00.
        // UI warns above 1.30 and marks 1.60~2.00 as extreme/special-effect range.
        let safeSpeed: Float = min(2.00, max(0.70, speed))
        let durScaled = durOnnx.map { $0 / safeSpeed }
        let wavLengths = durScaled.map { Int64(Double($0) * Double(sampleRate)) }
        let wavLenMax  = wavLengths.max() ?? 1
        let latentL    = Int((Double(wavLenMax) + Double(chunkSize) - 1.0) /
                             Double(chunkSize))
        let latentMask = makeLatentMask(wavLengths: wavLengths, latentLen: latentL)

        // Stage 2: Text encoder
        // text_ids:[1,T], style_ttl:[1,50,256], text_mask:[1,1,T] → text_emb:[1,T,256]
        let textEmb: [Float]
        let textEmbShape: [Int]
        do {
            let sess = try ortSession(env: env, modelPath: paths.textEncoderURL.path)
            let inputs: [String: ORTValue] = [
                "text_ids":  try makeTensorI64(textIds, shape: [1, seqLen]),
                "style_ttl": try makeTensorF32(style.styleTTL, shape: style.styleTTLShape),
                "text_mask": try makeTensorF32(textMask1T, shape: [1, 1, seqLen])
            ]
            let outs = try ortRun(sess, inputs: inputs, outputNames: ["text_emb"])
            guard let embVal = outs["text_emb"] else {
                throw Supertonic3ONNXRunnerError.missingOutput("text_emb")
            }
            textEmb = try floatArray(from: embVal)
            // tensorTypeAndShapeInfo() is a throwing method bridged from ObjC
            let shapeInfo = try embVal.tensorTypeAndShapeInfo()
            textEmbShape = shapeInfo.shape.map { $0.intValue }
        }

        // Stage 3: Vector estimator (flow matching, N steps)
        var xt = gaussianNoise(count: latentDim * latentL)
        // Apply latent mask to initial noise: xt[b, dim, frame] *= mask[frame]
        for frameIdx in 0..<latentL {
            let m = latentMask[frameIdx]
            for dimIdx in 0..<latentDim {
                xt[dimIdx * latentL + frameIdx] *= m
            }
        }

        // Stage 3: Vector estimator (flow matching, N steps)
        // Python: xt, *_ = vector_est_ort.run(None, {...})
        // 모델이 ODE step을 내부에서 처리하고 새 xt를 직접 반환한다 — Euler step 불필요.
        let veSess = try ortSession(env: env, modelPath: paths.vectorEstimatorURL.path)
        for step in 0..<totalSteps {
            let inputs: [String: ORTValue] = [
                "noisy_latent": try makeTensorF32(xt,             shape: [1, latentDim, latentL]),
                "text_emb":     try makeTensorF32(textEmb,        shape: textEmbShape),
                "style_ttl":    try makeTensorF32(style.styleTTL, shape: style.styleTTLShape),
                "text_mask":    try makeTensorF32(textMask1T,     shape: [1, 1, seqLen]),
                "latent_mask":  try makeTensorF32(latentMask,     shape: [1, 1, latentL]),
                "current_step": try makeTensorF32([Float(step)],  shape: [1]),
                "total_step":   try makeTensorF32([Float(totalSteps)], shape: [1])
            ]
            let outs = try ortRun(veSess, inputs: inputs, outputNames: ["denoised_latent"])
            xt = try floatArray(from: outs["denoised_latent"])
        }

        // Stage 4: Vocoder — latent:[1,144,L] → wav_tts:[1,N]
        let wavSamples: [Float]
        do {
            let sess = try ortSession(env: env, modelPath: paths.vocoderURL.path)
            let inputs: [String: ORTValue] = [
                "latent": try makeTensorF32(xt, shape: [1, latentDim, latentL])
            ]
            let outs = try ortRun(sess, inputs: inputs, outputNames: ["wav_tts"])
            wavSamples = try floatArray(from: outs["wav_tts"])
        }

        // Metrics
        let elapsedMs   = (CFAbsoluteTimeGetCurrent() - t0) * 1000.0
        let durationSec = Double(wavSamples.count) / Double(sampleRate)
        let rtf         = durationSec > 0 ? elapsedMs / (durationSec * 1000.0) : 0.0

        return Supertonic3SynthesisResult(
            wavSamples:       wavSamples,
            sampleRate:       sampleRate,
            durationSec:      durationSec,
            elapsedMs:        elapsedMs,
            realtimeFactor:   rtf,
            presetUsed:       preset,
            textLength:       seqLen,
            latentFrameCount: latentL
        )
    }

    // MARK: - ORT Helpers

    private func ortSession(env: ORTEnv, modelPath: String) throws -> ORTSession {
        do {
            return try ORTSession(env: env, modelPath: modelPath, sessionOptions: nil)
        } catch {
            throw Supertonic3ONNXRunnerError.inferenceFailure("ORTSession init failed [\(URL(fileURLWithPath: modelPath).lastPathComponent)]: \(error.localizedDescription)")
        }
    }

    private func ortRun(
        _ session: ORTSession,
        inputs: [String: ORTValue],
        outputNames: [String]
    ) throws -> [String: ORTValue] {
        let names = Set(outputNames)
        do {
            let result = try session.run(withInputs: inputs, outputNames: names, runOptions: nil)
            return result
        } catch {
            throw Supertonic3ONNXRunnerError.inferenceFailure("ORTSession.run failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Tensor Helpers

    /// Create Float32 ORTValue tensor. NSMutableData copies the array bytes.
    private func makeTensorF32(_ data: [Float], shape: [Int]) throws -> ORTValue {
        var mutable = data
        let nsData = NSMutableData(bytes: &mutable, length: mutable.count * MemoryLayout<Float>.stride)
        let nsShape = shape.map { NSNumber(value: $0) }
        guard let tensor = try? ORTValue(tensorData: nsData, elementType: .float, shape: nsShape) else {
            throw Supertonic3ONNXRunnerError.inferenceFailure("ORTValue(Float32) init failed")
        }
        return tensor
    }

    /// Create Int64 ORTValue tensor. NSMutableData copies the array bytes.
    private func makeTensorI64(_ data: [Int64], shape: [Int]) throws -> ORTValue {
        var mutable = data
        let nsData = NSMutableData(bytes: &mutable, length: mutable.count * MemoryLayout<Int64>.stride)
        let nsShape = shape.map { NSNumber(value: $0) }
        guard let tensor = try? ORTValue(tensorData: nsData, elementType: .int64, shape: nsShape) else {
            throw Supertonic3ONNXRunnerError.inferenceFailure("ORTValue(Int64) init failed")
        }
        return tensor
    }

    /// Extract [Float] from an ORTValue tensor.
    private func floatArray(from value: ORTValue?) throws -> [Float] {
        guard let value else {
            throw Supertonic3ONNXRunnerError.missingOutput("nil ORTValue")
        }
        guard let data = try? value.tensorData() as Data else {
            throw Supertonic3ONNXRunnerError.inferenceFailure("ORTValue.tensorData() failed")
        }
        return data.withUnsafeBytes { ptr in
            Array(ptr.bindMemory(to: Float.self))
        }
    }

    // MARK: - Latent Mask

    /// Python equivalent of get_latent_mask → length_to_mask. Returns [Float] shape [L].
    private func makeLatentMask(wavLengths: [Int64], latentLen: Int) -> [Float] {
        let chunkSize: Int = 3072  // S3Config.chunkSize — local constant avoids @MainActor default-isolation
        let wavLen = wavLengths.first ?? 0
        let latentLenForSeq = (Int(wavLen) + chunkSize - 1) / chunkSize
        return (0..<latentLen).map { $0 < latentLenForSeq ? 1.0 : 0.0 }
    }

    // MARK: - Gaussian Noise (Box-Muller Transform)

    /// Generate Gaussian noise using Box-Muller transform.
    /// Swift's Float.random() is uniform [0,1) — Box-Muller converts to N(0,1).
    private func gaussianNoise(count: Int) -> [Float] {
        var result = [Float](repeating: 0.0, count: count)
        var i = 0
        while i < count {
            let u1 = Float.random(in: Float.leastNormalMagnitude...1.0)
            let u2 = Float.random(in: 0.0...1.0)
            let mag = Foundation.sqrt(-2.0 * Foundation.log(u1))
            let z0  = mag * Foundation.cos(2.0 * Float.pi * u2)
            let z1  = mag * Foundation.sin(2.0 * Float.pi * u2)
            result[i] = z0
            if i + 1 < count { result[i + 1] = z1 }
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
