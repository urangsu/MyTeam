import Foundation
import AVFoundation
import MLX
@preconcurrency import OnnxRuntimeBindings

// MARK: - PrecomputedVoice (ve.onnx 런타임 완전 대체)
private struct PrecomputedVoice: Sendable {
    let veEmbed: [Float32]      // 256-dim → T3 speakerEmbedding
    let t3CondEmbeds: [Float32] // [34×1024] → T3 conditioning
    let t3CondLen: Int          // = 34
    let xvector: [Float32]      // 192-dim → s3gen_enc embedding
    let promptTokens: [Int64]   // [P] → s3gen_enc prompt_token
    let promptFeat: [Float32]   // [P×80] → s3gen_enc prompt_feat
    let promptFeatLen: Int      // P (프레임 수)

    nonisolated init(characterName: String) throws {
        let fileName = "\(characterName)_reference"
        // macOS HFS+/APFS가 한글 파일명을 NFD로 저장하므로 Bundle API 검색 실패.
        // resourcePath 직접 접근으로 폴백.
        func bundleURL() -> URL? {
            if let u = Bundle.main.url(forResource: fileName, withExtension: "json", subdirectory: "PrecomputedVoice") { return u }
            if let u = Bundle.main.url(forResource: characterName, withExtension: "json", subdirectory: "PrecomputedVoice") { return u }
            if let u = Bundle.main.url(forResource: characterName, withExtension: "json") { return u }
            // NFD 파일명 직접 경로 접근
            guard let rp = Bundle.main.resourcePath else { return nil }
            let candidates = [
                "\(rp)/PrecomputedVoice/\(characterName).json",
                "\(rp)/\(characterName).json"
            ]
            return candidates.compactMap { FileManager.default.fileExists(atPath: $0) ? URL(fileURLWithPath: $0) : nil }.first
        }
        guard let url = bundleURL()
        else { throw MLXModelError.weightsNotFound("PrecomputedVoice/\(characterName).json") }

        let raw  = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: raw) as! [String: Any]

        func f32(_ key: String) throws -> [Float32] {
            guard let b64   = json[key] as? String,
                  let bytes = Data(base64Encoded: b64, options: .ignoreUnknownCharacters)
            else { throw MLXModelError.weightsNotFound(key) }
            return bytes.withUnsafeBytes { Array($0.bindMemory(to: Float32.self)) }
        }
        func i64(_ key: String) throws -> [Int64] {
            guard let b64   = json[key] as? String,
                  let bytes = Data(base64Encoded: b64, options: .ignoreUnknownCharacters)
            else { throw MLXModelError.weightsNotFound(key) }
            return bytes.withUnsafeBytes { Array($0.bindMemory(to: Int64.self)) }
        }

        veEmbed       = try f32("ve_embed")
        t3CondEmbeds  = try f32("t3_cond_embeds")
        t3CondLen     = (json["t3_cond_shape"] as? [Int])?.first ?? 34
        xvector       = try f32("xvector")
        promptTokens  = try i64("prompt_tokens")
        promptFeat    = try f32("prompt_feat")
        let shape     = json["prompt_feat_shape"] as? [Int] ?? []
        promptFeatLen = shape.first ?? (promptFeat.count / 80)
    }
}

// MARK: - Global Actor
@globalActor
public actor InferenceActor {
    public static let shared = InferenceActor()
}

// MARK: - ONNX Session Pool

private final class OrtSessionPool: @unchecked Sendable {
    let env: ORTEnv
    let s3genEncSession: ORTSession
    let s3genCfmSession: ORTSession
    let hifiganSession:  ORTSession

    nonisolated init() throws {
        let e = try ORTEnv(loggingLevel: .warning)
        env = e

        func make(_ n: String, useCoreML: Bool = true) throws -> ORTSession {
            guard let url = Bundle.main.url(forResource: n, withExtension: "onnx", subdirectory: "onnx_models")
                         ?? Bundle.main.url(forResource: n, withExtension: "onnx")
            else { throw MLXModelError.weightsNotFound("\(n).onnx") }
            let opt = try ORTSessionOptions()
            if useCoreML {
                try opt.appendCoreMLExecutionProvider(with: ORTCoreMLExecutionProviderOptions())
            }
            return try ORTSession(env: e, modelPath: url.path, sessionOptions: opt)
        }

        s3genEncSession = try make("s3gen_enc",    useCoreML: true)
        s3genCfmSession = try make("s3gen_cfm",    useCoreML: false) // CoreML Broadcast 버그 회피
        hifiganSession  = try make("hifigan_full", useCoreML: false) // CoreML Dimension-0 버그 회피 (CPU 강제)
        print("[OrtSessionPool] ✅ 3개 ONNX 세션 초기화 완료 (Enc=CoreML, CFM/HiFi=CPU)")
    }
}

// MARK: - MLXInferenceService
@InferenceActor final class MLXInferenceService {
    static let shared = MLXInferenceService()

    private var sessionPool: OrtSessionPool?
    private var tokenizer:   BPETokenizer?
    private var voiceCache:  [String: PrecomputedVoice] = [:]

    // ── G-Stack: 동시 발화 / GPU 폭발 방지 순차 큐 ──
    private var speechTaskQueue: Task<Void, Error>?

    private init() {}

    func cancelCurrentInference() {
        speechTaskQueue?.cancel()
        speechTaskQueue = nil
        print("[MLXInferenceService] 🛑 추론 취소 (Barge-in)")
    }

    // MARK: - nonisolated 진입점 (기존 SpeechManager 호환)
    nonisolated func generateTTSStream(text: String, characterName: String) -> AsyncStream<Data> {
        AsyncStream(Data.self, bufferingPolicy: .unbounded) { continuation in
            Task { @InferenceActor in
                defer { continuation.finish() }
                do {
                    try await self.runInferencePipeline(
                        text: text, characterName: characterName, continuation: continuation)
                } catch {
                    print("[MLXInferenceService] ❌ 파이프라인 오류: \(error)")
                }
            }
        }
    }

    // MARK: - 큐 매니저 (Task Chaining)
    func runInferencePipeline(
        text: String,
        characterName: String,
        continuation: AsyncStream<Data>.Continuation
    ) async throws {
        let previousTask = speechTaskQueue
        let currentTask  = Task { @InferenceActor in
            _ = await previousTask?.result   // 앞 발화 완전히 끝날 때까지 대기
            try await self.performInference(text: text, characterName: characterName,
                                            continuation: continuation)
        }
        speechTaskQueue = currentTask
        try await currentTask.value
    }

    // MARK: - 실제 추론 엔진
    private func performInference(
        text: String,
        characterName: String,
        continuation: AsyncStream<Data>.Continuation
    ) async throws {

        // lazy 초기화 (첫 발화 시 1회)
        if sessionPool == nil {
            // actor 내부에서 수행되므로 이미 메인 스레드가 아님
            sessionPool = try OrtSessionPool()
        }
        
        if tokenizer == nil { tokenizer = try BPETokenizer() }
        
        guard let pool = sessionPool, let tok = tokenizer else {
            throw MLXModelError.weightsNotFound("세션/토크나이저 초기화 실패")
        }

        // 1. PrecomputedVoice (캐시 우선)
        let voice: PrecomputedVoice
        if let cached = voiceCache[characterName] {
            voice = cached
        } else {
            voice = try PrecomputedVoice(characterName: characterName)
            voiceCache[characterName] = voice
        }
        print("[MLXInferenceService] 🧠 \(characterName) 사전 계산 텐서 장착 완료")

        // 2. BPE 토크나이징
        let textTokenIds = tok.encode(text)
        print("[MLXInferenceService] 📝 토크나이징: \(text.prefix(20)) → \(textTokenIds.count)개")
        if Task.isCancelled { return }

        // 3. T3 AR 디코딩
        let t3Model   = try await MLXModelManager.shared.loadModelIfNeeded()
        let maxTokens = min(textTokenIds.count * 6, 600)
        var speechTokenIds = t3Model.generate(
            textTokenIds:     textTokenIds,
            t3CondEmbeds:     voice.t3CondEmbeds,
            t3CondLen:        voice.t3CondLen,
            maxTokens:        maxTokens,
            repetitionPenalty: 1.3
        )
        guard !speechTokenIds.isEmpty else {
            print("[MLXInferenceService] ❌ T3 디코딩 결과 없음"); return
        }

        // Conv 최소 시퀀스 패딩 (MIN=50)
        let MIN_SEQ = 50
        if speechTokenIds.count < MIN_SEQ {
            speechTokenIds += Array(repeating: Int32(0), count: MIN_SEQ - speechTokenIds.count)
        }
        if Task.isCancelled { return }

        // 4. S3Gen Encoder (tokens → mu, mask)
        let (mu, mask) = try runS3GenEncoder(speechTokenIds: speechTokenIds, session: pool.s3genEncSession)
        let melFrames = mu.count / 80   // 실제 mel 프레임 수 (토큰 수 ≠ T)
        print("[MLXInferenceService] 🌊 S3Gen Enc 완료 — mel frames: \(melFrames)")
        if Task.isCancelled { return }

        // 5. S3Gen CFM Euler ODE (mel 생성)
        let mel = try runS3GenCFMEuler(mu: mu, mask: mask, T: melFrames, voice: voice, session: pool.s3genCfmSession)
        print("[MLXInferenceService] 🎼 S3Gen CFM 완료 — mel shape: [1,80,\(melFrames)]")
        if Task.isCancelled { return }

        // 6. HiFiGAN magnitude+phase → ISTFT → PCM
        let tMel = try makeTensor(mel, shape: [1, 80, melFrames as NSNumber])

        let hifiInputNames = try pool.hifiganSession.inputNames()
        let inName = hifiInputNames.first ?? "mel"
        print("🚨 [진단] HiFiGAN 입력: \(hifiInputNames)")

        let hifiOut = try pool.hifiganSession.run(
            withInputs: [inName: tMel],
            outputNames: ["magnitude", "phase"],
            runOptions: nil
        )
        guard let magVal   = hifiOut["magnitude"],
              let phaseVal = hifiOut["phase"] else {
            throw MLXModelError.weightsNotFound("hifigan: magnitude/phase 없음")
        }

        let magnitude = try extractFloats(magVal)
        let phaseArr  = try extractFloats(phaseVal)
        let magShape  = try magVal.tensorTypeAndShapeInfo().shape.map { $0.intValue }
        let nFrames   = magShape[2]
        let nBins     = magShape[1]
        
        print("[MLXInferenceService] 🔊 HiFiGAN Output Shape: \(magShape), Magnitude Max: \(magnitude.max() ?? 0)")

        // ── G-Stack: ISTFT (주파수 스펙트럼 → PCM 파형) ──
        let pcmFloats = istft(magnitude: magnitude, phase: phaseArr,
                              nBins: nBins, nPhase: nBins - 1, nFrames: nFrames,
                              nFFT: (nBins - 1) * 2, hopLen: 4)
        print("[MLXInferenceService] 🔊 ISTFT 완료! PCM: \(pcmFloats.count)개 @ 24kHz")

        // 7. 4096 샘플 청킹 스트리밍
        var offset    = 0
        let chunkSize = 4096
        while offset < pcmFloats.count {
            if Task.isCancelled { break }
            let end   = min(offset + chunkSize, pcmFloats.count)
            let chunk = Array(pcmFloats[offset..<end])
            continuation.yield(Data(bytes: chunk, count: chunk.count * MemoryLayout<Float32>.stride))
            offset = end
        }
        print("[MLXInferenceService] ✅ \(characterName) Token-to-Audio 완료")
    }

    // MARK: - S3Gen Encoder
    private func runS3GenEncoder(
        speechTokenIds: [Int32],
        session: ORTSession
    ) throws -> (mu: [Float32], mask: [Float32]) {
        let tokensI64 = speechTokenIds.map { Int64($0) }
        let S = tokensI64.count
        let d = tokensI64.withUnsafeBytes { Data($0) }
        let tokT = try ORTValue(tensorData: NSMutableData(data: d),
                                elementType: .int64, shape: [1, S as NSNumber])

        let actualInputs  = try session.inputNames()
        let actualOutputs = try session.outputNames()
        print("🚨 [진단] S3Gen Enc 입력: \(actualInputs) | 출력: \(actualOutputs)")

        let inName  = actualInputs.first ?? "tokens"
        let outputs = try session.run(withInputs: [inName: tokT],
                                      outputNames: ["mu", "mask"], runOptions: nil)

        func extract(_ name: String) throws -> [Float32] {
            guard let v = outputs[name] else {
                throw MLXModelError.weightsNotFound("s3gen_enc:\(name)")
            }
            return try (v.tensorData() as Data).withUnsafeBytes {
                Array($0.bindMemory(to: Float32.self))
            }
        }
        return (try extract("mu"), try extract("mask"))
    }

    // MARK: - S3Gen CFM Euler ODE
    private func runS3GenCFMEuler(
        mu: [Float32], mask: [Float32], T: Int,
        voice: PrecomputedVoice, session: ORTSession
    ) throws -> [Float32] {
        let nSteps = 10
        let dt: Float32 = 1.0 / Float32(nSteps)
        let totalElements = 80 * T
        var x = [Float32](repeating: 0, count: totalElements)

        let tMask = try makeTensor(mask, shape: [1, 1,  T as NSNumber])
        let tMu   = try makeTensor(mu,   shape: [1, 80, T as NSNumber])

        // ── spks: promptFeat 시간 평균 → [1, 80] (화자 글로벌 임베딩) ──
        let P = voice.promptFeatLen   // 269 프레임
        var spksMean = [Float32](repeating: 0, count: 80)
        for frame in 0..<P {
            for dim in 0..<80 {
                spksMean[dim] += voice.promptFeat[frame * 80 + dim]
            }
        }
        if P > 0 { for i in 0..<80 { spksMean[i] /= Float32(P) } }
        let tSpks = try makeTensor(spksMean, shape: [1, 80])

        // ── cond: promptFeat를 T 프레임으로 선형 보간 → [1, 80, T] (레퍼런스 mel) ──
        // 메모리 레이아웃: shape [1,80,T] → condArray[dim * T + t]
        var condArray = [Float32](repeating: 0, count: 80 * T)
        for t in 0..<T {
            let ratio = (P <= 1) ? 0.0 : Float32(t) / Float32(T - 1) * Float32(P - 1)
            let lo    = min(Int(ratio), P - 1)
            let hi    = min(lo + 1, P - 1)
            let frac  = ratio - Float32(lo)
            for dim in 0..<80 {
                let loVal = voice.promptFeat[lo * 80 + dim]
                let hiVal = voice.promptFeat[hi * 80 + dim]
                condArray[dim * T + t] = loVal * (1 - frac) + hiVal * frac
            }
        }
        let tCond = try makeTensor(condArray, shape: [1, 80, T as NSNumber])

        let actualIn  = try session.inputNames()
        let actualOut = try session.outputNames()
        print("🚨 [진단] CFM 입력: \(actualIn) | 출력: \(actualOut)")
        print("[MLXInferenceService] 🔄 Euler ODE 시작 (\(nSteps) Steps, T=\(T), P=\(voice.promptFeatLen))")

        for step in 0..<nSteps {
            let tX    = try makeTensor(x,                         shape: [1, 80, T as NSNumber])
            let tTime = try makeTensor([Float32(step) * dt],      shape: [1])
            let out   = try session.run(
                withInputs: ["x": tX, "mask": tMask, "mu": tMu,
                             "t": tTime, "spks": tSpks, "cond": tCond],
                outputNames: ["dxdt"], runOptions: nil)
            let dxdt = try extractFloats(out["dxdt"]!)
            for i in 0..<totalElements { 
                let val = dxdt[i]
                if val.isNaN || val.isInfinite { continue }
                x[i] += dt * val 
            }
        }
        print("[MLXInferenceService] ✅ Euler ODE 완료")
        return x
    }

    // MARK: - ISTFT (n_fft=16, hop=4 — hifigan_full.onnx 고정 파라미터)
    private func istft(
        magnitude: [Float32], phase: [Float32],
        nBins: Int, nPhase: Int, nFrames: Int,
        nFFT: Int, hopLen: Int
    ) -> [Float32] {
        let audioLen  = (nFrames - 1) * hopLen + nFFT
        var output    = [Float32](repeating: 0, count: audioLen)
        var windowSum = [Float32](repeating: 0, count: audioLen)
        
        // Hann Window
        let window = (0..<nFFT).map { n -> Float32 in
            0.5 * (1 - cos(2 * Float32.pi * Float32(n) / Float32(nFFT)))
        }

        for frame in 0..<nFrames {
            var real = [Float32](repeating: 0, count: nFFT)
            var imag = [Float32](repeating: 0, count: nFFT)
            
            for k in 0..<nBins {
                let mag = magnitude[k * nFrames + frame]
                let ph  = phase[k * nFrames + frame]
                // NaNs check
                if mag.isNaN || mag.isInfinite || ph.isNaN || ph.isInfinite { continue }
                
                real[k] = mag * cos(ph)
                imag[k] = mag * sin(ph)
                
                // Hermitian symmetry for Real-IDFT
                if k > 0 && k < (nFFT / 2) {
                    real[nFFT - k] = real[k]
                    imag[nFFT - k] = -imag[k]
                }
            }
            
            var samples = [Float32](repeating: 0, count: nFFT)
            for n in 0..<nFFT {
                var s: Float32 = 0
                for k in 0..<nFFT {
                    let a = 2 * Float32.pi * Float32(k) * Float32(n) / Float32(nFFT)
                    s += real[k] * cos(a) - imag[k] * sin(a)
                }
                samples[n] = s / Float32(nFFT)
            }
            
            let off = frame * hopLen
            for n in 0..<nFFT where off + n < audioLen {
                let s = samples[n] * window[n]
                if s.isNaN || s.isInfinite { continue }
                output[off + n]    += s
                windowSum[off + n] += window[n] * window[n]
            }
        }
        
        for i in 0..<audioLen {
            if windowSum[i] > 1e-8 {
                output[i] /= windowSum[i]
            }
            // Final safety clip to [-1, 1]
            output[i] = max(-1.0, min(1.0, output[i]))
        }
        return output
    }

    // MARK: - ORT 헬퍼
    private func makeTensor<T>(_ array: [T], shape: [NSNumber]) throws -> ORTValue {
        // Bug 1 수정: Swift Array → withUnsafeBytes → Data 경유 (직접 전달 불가)
        let d = array.withUnsafeBytes { Data($0) }
        let elementType: ORTTensorElementDataType = (T.self == Float32.self) ? .float : .int64
        return try ORTValue(tensorData: NSMutableData(data: d), elementType: elementType, shape: shape)
    }

    private func extractFloats(_ value: ORTValue) throws -> [Float32] {
        return try (value.tensorData() as Data).withUnsafeBytes {
            Array($0.bindMemory(to: Float32.self))
        }
    }
}
