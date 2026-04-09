import Foundation
import AVFoundation
import MLX
@preconcurrency import OnnxRuntimeBindings

// MARK: - PrecomputedVoice (ve.onnx 런타임 완전 폐기 → JSON 사전계산 데이터)
/// 앱 번들 PrecomputedVoice/{characterName}.json에서 로드
/// ve_embed(T3용 256-dim), xvector(S3Gen용 192-dim), prompt_tokens, prompt_feat 제공
// ── G-Stack: Sendable 채택 및 nonisolated 강제 ──
private struct PrecomputedVoice: Sendable {
    let veEmbed: [Float32]      // [256] → T3 speakerEmbedding
    let xvector: [Float32]      // [192] → s3gen_enc embedding (CAMPlus)
    let promptTokens: [Int64]   // [P]   → s3gen_enc prompt_token
    let promptFeat: [Float32]   // [P×80] → s3gen_enc prompt_feat
    let promptFeatLen: Int      // P (time frames)

    nonisolated init(characterName: String) throws {
        guard let url = Bundle.main.url(forResource: characterName,
                                         withExtension: "json",
                                         subdirectory: "PrecomputedVoice")
               ?? Bundle.main.url(forResource: characterName, withExtension: "json")
        else {
            throw MLXModelError.weightsNotFound("PrecomputedVoice/\(characterName).json")
        }

        let raw = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: raw) as? [String: Any] else {
            throw MLXModelError.weightsNotFound("json parse 실패: \(characterName)")
        }

        func f32(_ key: String) throws -> [Float32] {
            guard let b64 = json[key] as? String,
                  let bytes = Data(base64Encoded: b64, options: .ignoreUnknownCharacters)
            else { throw MLXModelError.weightsNotFound("\(characterName).\(key)") }
            return bytes.withUnsafeBytes { ptr in Array(ptr.bindMemory(to: Float32.self)) }
        }
        func i64(_ key: String) throws -> [Int64] {
            guard let b64 = json[key] as? String,
                  let bytes = Data(base64Encoded: b64, options: .ignoreUnknownCharacters)
            else { throw MLXModelError.weightsNotFound("\(characterName).\(key)") }
            return bytes.withUnsafeBytes { ptr in Array(ptr.bindMemory(to: Int64.self)) }
        }

        veEmbed       = try f32("ve_embed")
        xvector       = try f32("xvector")
        promptTokens  = try i64("prompt_tokens")
        promptFeat    = try f32("prompt_feat")
        let shape     = json["prompt_feat_shape"] as? [Int] ?? []
        promptFeatLen = shape.first ?? (promptFeat.count / 80)
    }
}

// MARK: - ONNX Session Pool
@InferenceActor
private final class OrtSessionPool: @unchecked Sendable {
    let env: ORTEnv
    let s3genEncSession: ORTSession
    let s3genCfmSession: ORTSession
    let hifiganSession:  ORTSession

    init() throws {
        let e = try ORTEnv(loggingLevel: .warning)
        env = e

        func make(_ n: String, useCoreML: Bool = true) throws -> ORTSession {
            guard let url = Bundle.main.url(forResource: n, withExtension: "onnx", subdirectory: "onnx_models")
                         ?? Bundle.main.url(forResource: n, withExtension: "onnx")
                         ?? {
                             let p = "/Users/su/Desktop/MyTeam/MyTeam/Resources/onnx_models/\(n).onnx"
                             return FileManager.default.fileExists(atPath: p)
                                 ? URL(fileURLWithPath: p) : nil
                         }()
            else { throw MLXModelError.weightsNotFound("\(n).onnx") }
            let opt = try ORTSessionOptions()
            // G-Stack: CFM Broadcast 버그 방어 — CFM만 CPU 강제 할당
            if useCoreML {
                try opt.appendCoreMLExecutionProvider(with: ORTCoreMLExecutionProviderOptions())
            }
            return try ORTSession(env: e, modelPath: url.path, sessionOptions: opt)
        }

        s3genEncSession = try make("s3gen_enc",    useCoreML: true)
        s3genCfmSession = try make("s3gen_cfm",    useCoreML: false) // 🚨 CoreML Broadcast 버그 회피 → CPU
        hifiganSession  = try make("hifigan_full", useCoreML: true)
        print("[OrtSessionPool] ✅ 3개 ONNX 세션 초기화 완료 (Enc/HiFi=CoreML, CFM=CPU)")
    }
}

// MARK: - Global Actor
@globalActor
public actor InferenceActor {
    public static let shared = InferenceActor()
}

// MARK: - MLXInferenceService
@InferenceActor
final class MLXInferenceService: Sendable {
    static let shared = MLXInferenceService()

    private var currentInferenceTask: Task<Void, Never>?
    private var sessionPool: OrtSessionPool?
    private var tokenizer: BPETokenizer?
    private var voiceCache: [String: PrecomputedVoice] = [:]

    nonisolated private init() {
        Task { @InferenceActor in await self.initializeSessionsIfNeeded() }
    }

    func cancelCurrentInference() {
        currentInferenceTask?.cancel()
        currentInferenceTask = nil
        print("[MLXInferenceService] 🛑 추론 Task 강제 취소 (Barge-in)")
    }

    private func initializeSessionsIfNeeded() async {
        guard sessionPool == nil else { return }
        do {
            sessionPool = try OrtSessionPool()
            tokenizer   = try BPETokenizer()
            print("[MLXInferenceService] ✅ ONNX CoreML EP 세션 풀 + 토크나이저 준비 완료")
        } catch {
            print("[MLXInferenceService] ❌ 세션 초기화 실패: \(error)")
        }
    }

    // MARK: - Public Entry
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

    // MARK: - Full Inference Pipeline
    private func runInferencePipeline(
        text: String,
        characterName: String,
        continuation: AsyncStream<Data>.Continuation
    ) async throws {
        if sessionPool == nil { await initializeSessionsIfNeeded() }
        guard let pool = sessionPool, let tok = tokenizer else {
            print("[MLXInferenceService] ❌ 세션/토크나이저 미준비"); return
        }

        // ── 1. PrecomputedVoice 로드 (캐시 우선) ─────────────────────────
        let voice: PrecomputedVoice
        if let cached = voiceCache[characterName] {
            voice = cached
        } else {
            voice = try PrecomputedVoice(characterName: characterName)
            voiceCache[characterName] = voice
        }
        print("[MLXInferenceService] 🧠 \(characterName) PrecomputedVoice 장착 완료 — T3 AR 디코딩 시작")

        // ── 2. BPE 토크나이징 ─────────────────────────────────────────────
        let textTokenIds = tok.encode(text)
        print("[MLXInferenceService] 📝 토크나이징: \(text.prefix(20)) → \(textTokenIds.count)개 토큰")
        if Task.isCancelled { return }

        // ── 3. T3 AR 디코딩 (MLX FP16, veEmbed 256-dim) ──────────────────
        let t3Model = try await MLXModelManager.shared.loadModelIfNeeded()
        let maxTokens = min(textTokenIds.count * 6, 600)
        let speechTokenIds = t3Model.generate(
            textTokenIds: textTokenIds,
            speakerEmbedding: voice.veEmbed,
            maxTokens: maxTokens
        )
        guard !speechTokenIds.isEmpty else {
            print("[MLXInferenceService] ❌ T3 디코딩 결과 없음"); return
        }
        if Task.isCancelled { return }

        // ── 4. S3Gen Encoder (tokens 1개 → mu/mask) ──────────────────────
        let (mu, mask) = try autoreleasepool {
            try runS3GenEncoder(speechTokenIds: speechTokenIds,
                                session: pool.s3genEncSession)
        }
        print("[MLXInferenceService] 🌊 S3Gen Enc 완료 — mel frames: \(mu.count / 80)")
        if Task.isCancelled { return }

        // ── 5. S3Gen CFM — Euler ODE 10-Step Loop ────────────────────────
        let T = mu.count / 80
        let mel = try autoreleasepool {
            try runS3GenCFMEuler(mu: mu, mask: mask, T: T, voice: voice,
                                 session: pool.s3genCfmSession)
        }
        print("[MLXInferenceService] 🎼 S3Gen CFM Euler 완료 — mel shape: [1,80,\(mel.count / 80)]")
        if Task.isCancelled { return }

        // ── 6. HiFiGAN mel → PCM ─────────────────────────────────────────
        let pcm = try autoreleasepool {
            try runHiFiGAN(mel: mel, session: pool.hifiganSession)
        }
        print("[MLXInferenceService] 🔊 HiFiGAN 완료 — \(pcm.count) PCM 샘플")

        // ── 7. PCM → AsyncStream<Data> 청크 yield ─────────────────────────
        var offset = 0
        let chunkSize = 4096
        while offset < pcm.count {
            if Task.isCancelled { break }
            while await AudioPlaybackService.shared.getQueuedBufferCount() > 15 {
                try await Task.sleep(nanoseconds: 20_000_000)
                if Task.isCancelled { break }
            }
            if Task.isCancelled { break }
            let end = min(offset + chunkSize, pcm.count)
            let chunkData = Data(bytes: Array(pcm[offset..<end]),
                                 count: (end - offset) * MemoryLayout<Float32>.size)
            continuation.yield(chunkData)
            offset = end
        }
        print("[MLXInferenceService] ✅ \(characterName) Token-to-Audio 완료")
    }

    // MARK: - S3Gen Encoder
    /// 입력 1개 (실제 스캔 확인): tokens[1,S int64]
    /// 출력 2개 (실제 스캔 확인): mu[1,80,T], mask[1,1,T]
    private func runS3GenEncoder(
        speechTokenIds: [Int32],
        session: ORTSession
    ) throws -> (mu: [Float32], mask: [Float32]) {

        var tokensI64 = speechTokenIds.map { Int64($0) }
        let MIN_SEQ = 50
        if tokensI64.count < MIN_SEQ {
            tokensI64 += Array(repeating: Int64(0), count: MIN_SEQ - tokensI64.count)
            print("[MLXInferenceService] ⚠️ Conv 패딩: \(speechTokenIds.count) → \(tokensI64.count)")
        }
        let S = tokensI64.count
        let d = Data(bytes: tokensI64, count: S * MemoryLayout<Int64>.size)
        let tokT = try ORTValue(tensorData: NSMutableData(data: d),
                                 elementType: .int64, shape: [1, S as NSNumber])

        let actualInputs  = try session.inputNames()
        let actualOutputs = try session.outputNames()
        print("🚨 [진단 완료] S3Gen Enc 진짜 입력 노드: \(actualInputs)")
        print("🚨 [진단 완료] S3Gen Enc 진짜 출력 노드: \(actualOutputs)")

        let outputs = try session.run(
            withInputs: ["tokens": tokT],
            outputNames: ["mu", "mask"],
            runOptions: nil
        )

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

    // MARK: - Tensor 헬퍼
    private func makeTensor(_ floats: [Float32], shape: [NSNumber]) throws -> ORTValue {
        let d = Data(bytes: floats, count: floats.count * MemoryLayout<Float32>.size)
        return try ORTValue(tensorData: NSMutableData(data: d), elementType: .float, shape: shape)
    }

    private func extractFloats(_ value: ORTValue) throws -> [Float32] {
        return try (value.tensorData() as Data).withUnsafeBytes {
            Array($0.bindMemory(to: Float32.self))
        }
    }

    // MARK: - S3Gen CFM (Euler ODE 10-Step Loop)
    private func runS3GenCFMEuler(
        mu: [Float32],
        mask: [Float32],
        T: Int,
        voice: PrecomputedVoice,
        session: ORTSession
    ) throws -> [Float32] {
        let nSteps = 10
        let dt: Float32 = 1.0 / Float32(nSteps)
        let totalElements = 80 * T
        var x = [Float32](repeating: 0, count: totalElements)

        let tMask = try makeTensor(mask, shape: [1, 1, T as NSNumber])
        let tMu   = try makeTensor(mu,   shape: [1, 80, T as NSNumber])

        // ── G-Stack: spks 80차원 규격 강제 (192차원 xvector 주입 에러 파괴) ──
        let spksArray = Array(repeating: Float32(0.0), count: 80)
        let tSpks = try makeTensor(spksArray, shape: [1, 80])
        // ── G-Stack: cond 텐서 길이(T) 강제 일치 (269 vs 100 에러 파괴) ──
        let P = voice.promptFeatLen // 🚨 print문 에러 방지용 복구
        let condArray = Array(repeating: Float32(0.0), count: 80 * T)
        let tCond = try makeTensor(condArray, shape: [1, 80, T as NSNumber])

        // G-Stack: CFM 실제 노드명 1회 스캔
        let actualInputs  = try session.inputNames()
        let actualOutputs = try session.outputNames()
        print("🚨 [진단 완료] S3Gen CFM 진짜 입력 노드: \(actualInputs)")
        print("🚨 [진단 완료] S3Gen CFM 진짜 출력 노드: \(actualOutputs)")
        print("[MLXInferenceService] 🔄 Euler ODE 적분 시작 (\(nSteps) Steps, T=\(T), P=\(P))")

        for step in 0..<nSteps {
            let tX    = try makeTensor(x,                   shape: [1, 80, T as NSNumber])
            let tTime = try makeTensor([Float32(step) * dt], shape: [1])

            let outputs = try session.run(
                withInputs: ["x": tX, "mask": tMask, "mu": tMu,
                             "t": tTime, "spks": tSpks, "cond": tCond],
                outputNames: ["dxdt"],
                runOptions: nil
            )
            guard let dxdtV = outputs["dxdt"] else {
                throw MLXModelError.weightsNotFound("s3gen_cfm:dxdt (step \(step))")
            }
            let dxdt = try extractFloats(dxdtV)
            for i in 0..<totalElements { x[i] += dt * dxdt[i] }
        }

        print("[MLXInferenceService] ✅ Euler ODE 적분 완료 → Mel 생성됨")
        return x
    }

    // MARK: - HiFiGAN
    /// 입력: mel[1,80,T] / 출력: audio
    private func runHiFiGAN(mel: [Float32], session: ORTSession) throws -> [Float32] {
        let T = mel.count / 80
        let d = Data(bytes: mel, count: mel.count * MemoryLayout<Float32>.size)
        let melT = try ORTValue(tensorData: NSMutableData(data: d),
                                 elementType: .float,
                                 shape: [1, 80, T as NSNumber])
        let outputs = try session.run(
            withInputs: ["mel": melT],
            outputNames: ["audio"],
            runOptions: nil
        )
        guard let audio = outputs["audio"] else {
            throw MLXModelError.weightsNotFound("hifigan:audio")
        }
        return try (audio.tensorData() as Data).withUnsafeBytes {
            Array($0.bindMemory(to: Float32.self))
        }
    }
}
