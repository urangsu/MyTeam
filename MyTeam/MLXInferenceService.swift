import Foundation
import AVFoundation
import MLX
@preconcurrency import OnnxRuntimeBindings

// MARK: - ONNX Session Pool (CoreML EP 강제)
/// s3gen_enc, s3gen_cfm, hifigan_full, ve 세션을 CoreML EP로 초기화
/// CoreML EP: ANE(Apple Neural Engine) 또는 GPU 위에서 직접 추론 — CPU 폴백 불허
@InferenceActor
private final class OrtSessionPool: @unchecked Sendable {
    let env: ORTEnv
    let veSession: ORTSession          // Voice Encoder: 참조 오디오 → 화자 임베딩
    let s3genEncSession: ORTSession    // S3Gen Encoder: speech tokens → mu/mask
    let s3genCfmSession: ORTSession    // S3Gen CFM: Euler ODE → mel
    let hiifiganSession: ORTSession    // HiFiGAN: mel → PCM Float32

    // G-Stack 원칙: 모든 세션에 CoreML EP 강제 적용 (ANE/GPU 가속)
    private static func makeSession(env: ORTEnv, modelName: String, subdirectory: String = "onnx_models") throws -> ORTSession {
        guard let modelURL = Bundle.main.url(
            forResource: modelName, withExtension: "onnx", subdirectory: subdirectory
        ) ?? {
            let devPath = "/Users/su/Desktop/TTS맨/chatterbox/onnx_models/\(modelName).onnx"
            return FileManager.default.fileExists(atPath: devPath) ? URL(fileURLWithPath: devPath) : nil
        }() else {
            throw MLXModelError.weightsNotFound("\(modelName).onnx")
        }

        let options = try ORTSessionOptions()
        // CoreML EP: flags=0 → ANE 우선, GPU 폴백 (CPU 폴백 없음)
        try options.appendCoreMLExecutionProvider(with: ORTCoreMLExecutionProviderOptions())
        return try ORTSession(env: env, modelPath: modelURL.path, sessionOptions: options)
    }

    init() throws {
        let e = try ORTEnv(loggingLevel: .warning)
        env = e
        veSession       = try Self.makeSession(env: e, modelName: "ve")
        s3genEncSession = try Self.makeSession(env: e, modelName: "s3gen_enc")
        s3genCfmSession = try Self.makeSession(env: e, modelName: "s3gen_cfm")
        hiifiganSession = try Self.makeSession(env: e, modelName: "hifigan_full")

        print("[OrtSessionPool] ✅ 4개 ONNX 세션 초기화 완료 (CoreML EP — ANE/GPU 전용)")
    }
}

// BPETokenizer를 외부 클래스로 분리하여 Jamo Split 및 정확한 텍스트 디코딩을 수행합니다.

@globalActor
public actor InferenceActor {
    public static let shared = InferenceActor()
}

// MARK: - MLXInferenceService (실제 T3 → ONNX 파이프라인)
@InferenceActor
final class MLXInferenceService: Sendable {
    static let shared = MLXInferenceService()

    private var currentInferenceTask: Task<Void, Never>?
    private var sessionPool: OrtSessionPool?
    private var tokenizer: BPETokenizer?

    nonisolated private init() {
        // ONNX 세션 사전 초기화 (앱 시작 시 ANE 워밍업)
        Task { @InferenceActor in
            await self.initializeSessionsIfNeeded()
        }
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
            tokenizer = try BPETokenizer()
            print("[MLXInferenceService] ✅ ONNX CoreML EP 세션 풀 + 토크나이저 준비 완료")
        } catch {
            print("[MLXInferenceService] ❌ 세션 초기화 실패: \(error)")
        }
    }

    // MARK: - Token-to-Audio Stream (SSE 파이프라인 직결)
    nonisolated func generateTTSStream(
        text: String,
        characterName: String
    ) -> AsyncStream<Data> {
        AsyncStream(Data.self, bufferingPolicy: .unbounded) { continuation in
            Task { @InferenceActor in
                defer { continuation.finish() }

                do {
                    try await self.runInferencePipeline(
                        text: text,
                        characterName: characterName,
                        continuation: continuation
                    )
                } catch {
                    print("[MLXInferenceService] ❌ 파이프라인 오류: \(error)")
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - Full Inference Pipeline
    /// Text → BPE → T3(MLX) → S3Gen(CoreML) → HiFiGAN(CoreML) → PCM 청크
    private func runInferencePipeline(
        text: String,
        characterName: String,
        continuation: AsyncStream<Data>.Continuation
    ) async throws {
        // 세션 준비 (이미 완료됐을 가능성 높음)
        if sessionPool == nil { await initializeSessionsIfNeeded() }
        guard let pool = sessionPool, let tok = tokenizer else {
            print("[MLXInferenceService] ❌ 세션/토크나이저 미준비")
            return
        }

        // 1. T3 모델 + 레퍼런스 텐서 확보
        let t3Model = try await MLXModelManager.shared.loadModelIfNeeded()
        guard let refTensor = await MLXModelManager.shared.loadReferenceAudioIfNeeded(characterName: characterName) else {
            print("[MLXInferenceService] ❌ \(characterName) 레퍼런스 텐서 없음")
            return
        }

        print("[MLXInferenceService] 🧠 \(characterName) 레퍼런스 텐서 장착 완료 — T3 AR 디코딩 시작")

        // 2. BPE 토크나이저
        let textTokenIds = tok.encode(text)
        print("[MLXInferenceService] 📝 토크나이징: \(text.prefix(20)) → \(textTokenIds.count)개 토큰")

        if Task.isCancelled { return }

        // 3. 화자 임베딩 추출 (ve.onnx — CoreML EP)
        let xvector = try autoreleasepool {
            try extractSpeakerEmbedding(
                referenceTensor: refTensor,
                session: pool.veSession
            )
        }
        print("[MLXInferenceService] 🎤 화자 임베딩 추출 완료 (\(xvector.count)-dim)")

        if Task.isCancelled { return }

        // 4. T3 AR 디코딩 → 음성 토큰 (MLX, FP16, KV Cache)
        let maxTokens = min(textTokenIds.count * 6, 600)
        let speechTokenIds = t3Model.generate(
            textTokenIds: textTokenIds,
            speakerEmbedding: xvector,
            maxTokens: maxTokens
        )
        guard !speechTokenIds.isEmpty else {
            print("[MLXInferenceService] ❌ T3 디코딩 결과 없음")
            return
        }

        if Task.isCancelled { return }

        // 5. S3Gen Encoder: speech tokens → mu/mask/conds (CoreML EP)
        let (mu, mask, conds) = try autoreleasepool {
            try runS3GenEncoder(
                speechTokenIds: speechTokenIds,
                referenceTokens: speechTokenIds,  // speech_cond_prompt_len개 앞부분 사용
                xvector: xvector,
                session: pool.s3genEncSession
            )
        }
        print("[MLXInferenceService] 🌊 S3Gen Enc 완료 — mu shape: \(mu.count)")

        if Task.isCancelled { return }

        // 6. S3Gen CFM ODE: Euler 5 steps → mel spectrogram (CoreML EP)
        let mel = try autoreleasepool {
            try runS3GenCFM(
                mu: mu,
                mask: mask,
                conds: conds,
                xvector: xvector,
                session: pool.s3genCfmSession
            )
        }
        print("[MLXInferenceService] 🎼 S3Gen CFM 완료 — mel frames: \(mel.count / 80)")

        if Task.isCancelled { return }

        // 7. HiFiGAN: mel → PCM Float32 청크 단위 yield (CoreML EP)
        let pcmChunkSize = 4096
        let pcm = try autoreleasepool {
            try runHiFiGAN(mel: mel, session: pool.hiifiganSession)
        }
        print("[MLXInferenceService] 🔊 HiFiGAN 완료 — \(pcm.count) PCM 샘플")

        // 8. PCM → AsyncStream<Data> 청크 yield (백프레셔 모니터링)
        var offset = 0
        while offset < pcm.count {
            if Task.isCancelled { break }

            // 백프레셔: 재생 큐 15개 초과 시 Suspend
            while await AudioPlaybackService.shared.getQueuedBufferCount() > 15 {
                try await Task.sleep(nanoseconds: 20_000_000)
                if Task.isCancelled { break }
            }
            if Task.isCancelled { break }

            let end = min(offset + pcmChunkSize, pcm.count)
            let chunk = Array(pcm[offset..<end])
            let chunkData = chunk.withUnsafeBytes { src in
                Data(bytes: src.baseAddress!, count: src.count)
            }
            continuation.yield(chunkData)
            offset = end
        }

        print("[MLXInferenceService] ✅ \(characterName) Token-to-Audio 완료")
    }

    // MARK: - VoiceEncoder (ve.onnx)
    /// 레퍼런스 WAV Float32 텐서 → 256-dim xvector
    private func extractSpeakerEmbedding(
        referenceTensor: MLXArray,
        session: ORTSession
    ) throws -> [Float32] {
        // refTensor: (num_samples,) @ 24kHz → 모델은 16kHz 필요할 수 있음 (ve.onnx 스펙 확인 필요)
        let floats = referenceTensor.asArray(Float.self)

        let inputShape: [NSNumber] = [1, floats.count as NSNumber]
        let inputData = Data(bytes: floats, count: floats.count * MemoryLayout<Float32>.size)
        let inputTensor = try ORTValue(tensorData: NSMutableData(data: inputData),
                                       elementType: .float,
                                       shape: inputShape)

        let outputs = try session.run(
            withInputs: ["input": inputTensor],
            outputNames: ["xvector"],
            runOptions: nil
        )
        guard let output = outputs["xvector"] else { throw MLXModelError.weightsNotFound("ve output") }
        let outData = try output.tensorData() as Data
        return outData.withUnsafeBytes { Array($0.bindMemory(to: Float32.self)) }
    }

    // MARK: - S3Gen Encoder (s3gen_enc.onnx)
    private func runS3GenEncoder(
        speechTokenIds: [Int32],
        referenceTokens: [Int32],
        xvector: [Float32],
        session: ORTSession
    ) throws -> (mu: [Float32], mask: [Float32], conds: [Float32]) {
        // ── G-Stack 안전장치: ONNX Conv 커널 최소 시퀀스 강제 패딩 ──
        // s3gen_enc Conv 레이어 최소 커널 크기 16~30 → 50으로 넉넉하게 패딩
        let MIN_SEQ_LEN = 50
        var paddedTokenIds = speechTokenIds
        if paddedTokenIds.count < MIN_SEQ_LEN {
            let padCount = MIN_SEQ_LEN - paddedTokenIds.count
            paddedTokenIds = paddedTokenIds + Array(repeating: Int32(0), count: padCount)
            print("[MLXInferenceService] ⚠️ ONNX 패딩 적용: \(speechTokenIds.count) → \(paddedTokenIds.count) tokens (MIN=50, Conv 커널 보호)")
        }

        let T = paddedTokenIds.count
        let condLen = min(referenceTokens.count, 150)

        // tokens: (1, T)
        let tokData = Data(bytes: paddedTokenIds, count: T * MemoryLayout<Int32>.size)
        let tokTensor = try ORTValue(tensorData: NSMutableData(data: tokData),
                                      elementType: .int32,
                                      shape: [1, T as NSNumber])

        // prompt_tokens: (1, condLen)
        let promptTokens = Array(referenceTokens.prefix(condLen))
        let promptData = Data(bytes: promptTokens, count: promptTokens.count * MemoryLayout<Int32>.size)
        let promptTensor = try ORTValue(tensorData: NSMutableData(data: promptData),
                                         elementType: .int32,
                                         shape: [1, condLen as NSNumber])

        // xvector: (1, 256)
        let xvData = Data(bytes: xvector, count: xvector.count * MemoryLayout<Float32>.size)
        let xvTensor = try ORTValue(tensorData: NSMutableData(data: xvData),
                                     elementType: .float,
                                     shape: [1, 256])

        let outputs = try session.run(
            withInputs: ["tokens": tokTensor, "prompt_tokens": promptTensor, "xvector": xvTensor],
            outputNames: ["mu", "mask", "conds"],
            runOptions: nil
        )

        func extractFloat(_ name: String) throws -> [Float32] {
            guard let v = outputs[name] else { throw MLXModelError.weightsNotFound("s3gen_enc:\(name)") }
            return try (v.tensorData() as Data).withUnsafeBytes { Array($0.bindMemory(to: Float32.self)) }
        }

        return (try extractFloat("mu"), try extractFloat("mask"), try extractFloat("conds"))
    }

    // MARK: - S3Gen CFM (s3gen_cfm.onnx) — Euler 5 steps
    private func runS3GenCFM(
        mu: [Float32],
        mask: [Float32],
        conds: [Float32],
        xvector: [Float32],
        session: ORTSession
    ) throws -> [Float32] {
        func makeTensor(_ data: [Float32], shape: [NSNumber]) throws -> ORTValue {
            let d = Data(bytes: data, count: data.count * MemoryLayout<Float32>.size)
            return try ORTValue(tensorData: NSMutableData(data: d), elementType: .float, shape: shape)
        }

        let melLen = mu.count / 80  // mel_dim=80
        let muT    = try makeTensor(mu,     shape: [1, melLen as NSNumber, 80])
        let maskT  = try makeTensor(mask,   shape: [1, 1, melLen as NSNumber])
        let condsT = try makeTensor(conds,  shape: [1, melLen as NSNumber, 80])
        let xvT    = try makeTensor(xvector, shape: [1, 256])

        let outputs = try session.run(
            withInputs: ["mu": muT, "mask": maskT, "conds": condsT, "xvector": xvT],
            outputNames: ["mel"],
            runOptions: nil
        )
        guard let mel = outputs["mel"] else { throw MLXModelError.weightsNotFound("s3gen_cfm:mel") }
        return try (mel.tensorData() as Data).withUnsafeBytes { Array($0.bindMemory(to: Float32.self)) }
    }

    // MARK: - HiFiGAN (hifigan_full.onnx)
    private func runHiFiGAN(mel: [Float32], session: ORTSession) throws -> [Float32] {
        let melLen = mel.count / 80
        let melData = Data(bytes: mel, count: mel.count * MemoryLayout<Float32>.size)
        let melTensor = try ORTValue(tensorData: NSMutableData(data: melData),
                                      elementType: .float,
                                      shape: [1, 80, melLen as NSNumber])

        let outputs = try session.run(
            withInputs: ["mel": melTensor],
            outputNames: ["audio"],
            runOptions: nil
        )
        guard let audio = outputs["audio"] else { throw MLXModelError.weightsNotFound("hifigan:audio") }
        return try (audio.tensorData() as Data).withUnsafeBytes { Array($0.bindMemory(to: Float32.self)) }
    }
}
