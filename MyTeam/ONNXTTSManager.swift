import Foundation
import AVFoundation
import Accelerate
import AppKit
import OnnxRuntimeBindings

// ============================================================
// ONNXTTSManager.swift
// Chatterbox 완전 온디바이스 추론 (HTTP 서버 없음)
//
// 파이프라인:
//   텍스트 → 한글 자모 분리 → BPE 토크나이저 → T3 토큰 생성
//   → S3Gen 플로우 매칭 → HiFiGAN → PCM 오디오 스트림
//
// 의존성: onnxruntime-swift-package-manager (Microsoft)
//   Package URL: https://github.com/microsoft/onnxruntime-swift-package-manager
//
// Pre-computed 데이터:
//   cam_plus / s3tokenizer ONNX export 실패 우회
//   → Python에서 캐릭터별 speaker embedding, prompt tokens 미리 계산
//   → Resources/PrecomputedVoice/{캐릭터}.json
// ============================================================

/// ONNX 온디바이스 TTS 매니저 (HTTP 서버 불필요)
final class ONNXTTSManager: NSObject {
    static let shared = ONNXTTSManager()

    // MARK: - 상태
    private(set) var isReady: Bool = false
    private(set) var isSpeaking: Bool = false

    // MARK: - 오디오 엔진
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let pitchNode = AVAudioUnitTimePitch()

    private let engineFormat: AVAudioFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 24000,
        channels: 1,
        interleaved: false
    )!

    var onSpeakComplete: ((_ success: Bool) -> Void)?

    // MARK: - ONNX 모델 경로
    private lazy var modelDir: URL? = {
        // 배포: 번들 내 onnx_models
        if let url = Bundle.main.url(forResource: "onnx_models", withExtension: nil) { return url }
        // 개발/다운로드: 샌드박스 허용되는 Application Support 경로
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dev = appSupport.appendingPathComponent("MyTeam/onnx_models")
            if FileManager.default.fileExists(atPath: dev.path) { return dev }
        }
        return nil
    }()

    // MARK: - ONNX 세션
    private var ortEnv: ORTEnv?
    private var t3PrefillSession: ORTSession?
    private var t3DecodeSession: ORTSession?
    private var s3genEncSession: ORTSession?
    private var s3genCfmSession: ORTSession?
    private var hifiganF0Session: ORTSession?
    private var hifiganSession: ORTSession?

    // MARK: - 토크나이저 (BPE)
    private var bpeVocab: [String: Int] = [:]
    private var bpeMerges: [(String, String)] = []

    // MARK: - Pre-computed 캐릭터 데이터
    struct PrecomputedVoice {
        let veEmbed: [Float]           // [256] T3 speaker conditioning (legacy)
        let xvector: [Float]           // [192] S3Gen speaker embedding
        let promptTokens: [Int64]      // [≤150] S3Gen prompt tokens
        let promptFeat: [Float]        // [T×80] S3Gen prompt mel (row-major)
        let promptFeatShape: [Int]     // [T, 80]
        let t3CondEmbeds: [Float]      // [len_cond × 1024] T3 full conditioning (spkr + perceiver)
        let t3CondEmbedsShape: [Int]   // [len_cond, 1024]
    }
    private var precomputedVoices: [String: PrecomputedVoice] = [:]

    // MARK: - 모델 설정
    private var startTextToken: Int = 255
    private var stopTextToken: Int = 0
    private var startSpeechToken: Int = 6561
    private var stopSpeechToken: Int = 6562
    private var speechVocabSize: Int = 8194
    private var textVocabSize: Int = 2454
    private var maxSpeechTokens: Int = 4096
    private var hiddenSize: Int = 1024
    private var nLayers: Int = 30
    private var nHeads: Int = 16
    private var headDim: Int = 64

    // MARK: - T3 임베딩 가중치 (.npy에서 로드)
    private var textEmbWeights: [Float] = []       // [2454 × 1024]
    private var speechEmbWeights: [Float] = []     // [8194 × 1024]
    private var textPosEmbWeights: [Float] = []    // [2050 × 1024]
    private var speechPosEmbWeights: [Float] = []  // [4100 × 1024]
    private var speechHeadWeights: [Float] = []    // [8194 × 1024]
    // cond_enc
    private var spkrEncWeight: [Float] = []        // [1024 × 256]
    private var spkrEncBias: [Float] = []          // [1024]

    // MARK: - 초기화

    private override init() {
        super.init()
        setupAudioEngine()
        // CoreML EP 초기화가 main thread에서 실행되면 UI 블로킹 + 경고 수백 개
        // → 반드시 백그라운드 스레드에서 로딩
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.loadAll()
        }
    }

    private func setupAudioEngine() {
        audioEngine.attach(playerNode)
        audioEngine.attach(pitchNode)
        audioEngine.connect(playerNode, to: pitchNode, format: engineFormat)
        audioEngine.connect(pitchNode, to: audioEngine.mainMixerNode, format: engineFormat)
        audioEngine.prepare()
        do {
            try audioEngine.start()
            print("[ONNXTTS] ✅ 오디오 엔진 시작")
        } catch {
            print("[ONNXTTS] ❌ 오디오 엔진 실패: \(error)")
        }
    }

    private func loadAll() async {
        guard let dir = modelDir else {
            print("[ONNXTTS] ❌ ONNX 모델 폴더 없음")
            return
        }

        // 1. manifest.json
        loadManifest(dir: dir)

        // 2. BPE 토크나이저
        loadTokenizer(dir: dir)

        // 3. Pre-computed 캐릭터 데이터
        loadPrecomputedVoices()

        // 4. T3 임베딩 가중치 로드
        loadEmbeddingWeights(dir: dir)

        // 5. ONNX 세션 로드
        loadOrtSessions(dir: dir)

        if ortEnv != nil && t3PrefillSession != nil {
            isReady = true
            print("[ONNXTTS] ✅ ONNX 온디바이스 모드 준비 완료")
        } else {
            print("[ONNXTTS] ⚠️ 일부 모델 로드 실패 — 폴백 모드")
        }
    }

    // MARK: - Manifest 로드

    private func loadManifest(dir: URL) {
        let path = dir.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[ONNXTTS] ❌ manifest.json 로드 실패")
            return
        }

        // t3_prefill에서 설정 읽기
        if let t3p = json["t3_prefill"] as? [String: Any] {
            hiddenSize = t3p["hidden_size"] as? Int ?? 1024
            nLayers = t3p["n_layers"] as? Int ?? 30
            nHeads = t3p["n_heads"] as? Int ?? 16
            headDim = t3p["head_dim"] as? Int ?? 64
            speechVocabSize = t3p["speech_vocab_size"] as? Int ?? 8194
        }

        if let info = json["model_info"] as? [String: Any],
           let t3 = info["t3"] as? [String: Any] {
            hiddenSize = t3["hidden_size"] as? Int ?? hiddenSize
            nLayers = t3["n_layers"] as? Int ?? nLayers
        }

        // t3_config.json (추가 토큰 설정)
        let configPath = dir.appendingPathComponent("t3_config.json")
        if let cData = try? Data(contentsOf: configPath),
           let cfg = try? JSONSerialization.jsonObject(with: cData) as? [String: Any] {
            startTextToken = cfg["start_text_token"] as? Int ?? startTextToken
            stopTextToken = cfg["stop_text_token"] as? Int ?? stopTextToken
            startSpeechToken = cfg["start_speech_token"] as? Int ?? startSpeechToken
            stopSpeechToken = cfg["stop_speech_token"] as? Int ?? stopSpeechToken
            textVocabSize = cfg["text_vocab_size"] as? Int ?? textVocabSize
            speechVocabSize = cfg["speech_vocab_size"] as? Int ?? speechVocabSize
        }

        print("[ONNXTTS] ✅ manifest 로드 (hidden=\(hiddenSize), layers=\(nLayers), textVocab=\(textVocabSize), speechVocab=\(speechVocabSize))")
    }

    // MARK: - BPE 토크나이저 로드

    private func loadTokenizer(dir: URL) {
        let path = dir.appendingPathComponent("grapheme_mtl_merged_expanded_v1.json")
        guard let data = try? Data(contentsOf: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[ONNXTTS] ❌ 토크나이저 JSON 로드 실패")
            return
        }

        if let model = json["model"] as? [String: Any],
           let vocab = model["vocab"] as? [String: Int] {
            self.bpeVocab = vocab
        }

        if let model = json["model"] as? [String: Any],
           let merges = model["merges"] as? [String] {
            self.bpeMerges = merges.compactMap { merge -> (String, String)? in
                let parts = merge.split(separator: " ", maxSplits: 1)
                guard parts.count == 2 else { return nil }
                return (String(parts[0]), String(parts[1]))
            }
        }

        print("[ONNXTTS] ✅ BPE 토크나이저 로드 (어휘 \(bpeVocab.count)개, 병합 \(bpeMerges.count)개)")
    }

    // MARK: - Pre-computed 캐릭터 데이터 로드

    private func loadPrecomputedVoices() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let searchDirs = [
            Bundle.main.resourceURL?.appendingPathComponent("PrecomputedVoice"),
            appSupport?.appendingPathComponent("MyTeam/PrecomputedVoice")
        ].compactMap { $0 }

        for dir in searchDirs {
            guard FileManager.default.fileExists(atPath: dir.path),
                  let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }

            for file in files where file.pathExtension == "json" {
                guard let data = try? Data(contentsOf: file),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let name = json["character"] as? String else { continue }

                guard let veB64 = json["ve_embed"] as? String,
                      let xvB64 = json["xvector"] as? String,
                      let ptB64 = json["prompt_tokens"] as? String,
                      let pfB64 = json["prompt_feat"] as? String,
                      let pfShape = json["prompt_feat_shape"] as? [Int] else { continue }

                let ve = base64ToFloatArray(veB64)
                let xv = base64ToFloatArray(xvB64)
                let pt = base64ToInt64Array(ptB64)
                let pf = base64ToFloatArray(pfB64)

                // T3 conditioning (spkr + perceiver) — 없으면 빈 배열
                let t3CondB64 = json["t3_cond_embeds"] as? String ?? ""
                let t3CondShape = json["t3_cond_embeds_shape"] as? [Int] ?? []
                let t3Cond = t3CondB64.isEmpty ? [Float]() : base64ToFloatArray(t3CondB64)

                precomputedVoices[name] = PrecomputedVoice(
                    veEmbed: ve, xvector: xv, promptTokens: pt,
                    promptFeat: pf, promptFeatShape: pfShape,
                    t3CondEmbeds: t3Cond, t3CondEmbedsShape: t3CondShape
                )
                let condLen = t3CondShape.first ?? 0
                print("[ONNXTTS] ✅ \(name) pre-computed 로드 (ve=\(ve.count), xv=\(xv.count), cond=\(condLen)×1024, mel=\(pfShape))")
            }
            if !precomputedVoices.isEmpty { break }
        }

        print("[ONNXTTS] 캐릭터 \(precomputedVoices.count)개 로드 완료")
    }

    private func base64ToFloatArray(_ b64: String) -> [Float] {
        guard let data = Data(base64Encoded: b64) else { return [] }
        return data.withUnsafeBytes { ptr in
            Array(ptr.bindMemory(to: Float.self))
        }
    }

    private func base64ToInt64Array(_ b64: String) -> [Int64] {
        guard let data = Data(base64Encoded: b64) else { return [] }
        return data.withUnsafeBytes { ptr in
            Array(ptr.bindMemory(to: Int64.self))
        }
    }

    // MARK: - T3 임베딩 가중치 로드

    private func loadEmbeddingWeights(dir: URL) {
        textEmbWeights = loadNpy(dir.appendingPathComponent("text_emb.npy"))
        speechEmbWeights = loadNpy(dir.appendingPathComponent("speech_emb.npy"))
        textPosEmbWeights = loadNpy(dir.appendingPathComponent("text_pos_emb.npy"))
        speechPosEmbWeights = loadNpy(dir.appendingPathComponent("speech_pos_emb.npy"))
        speechHeadWeights = loadNpy(dir.appendingPathComponent("speech_head.npy"))
        spkrEncWeight = loadNpy(dir.appendingPathComponent("spkr_enc_weight.npy"))
        spkrEncBias = loadNpy(dir.appendingPathComponent("spkr_enc_bias.npy"))

        if textEmbWeights.isEmpty || speechEmbWeights.isEmpty {
            print("[ONNXTTS] ❌ 임베딩 가중치 로드 실패 — .npy 파일 확인 필요")
        } else {
            print("[ONNXTTS] ✅ 임베딩 가중치 로드: text=\(textEmbWeights.count/hiddenSize)×\(hiddenSize), speech=\(speechEmbWeights.count/hiddenSize)×\(hiddenSize)")
        }
    }

    /// NumPy .npy 파일 로드 (float32 배열만 지원)
    private func loadNpy(_ url: URL) -> [Float] {
        guard let data = try? Data(contentsOf: url), data.count > 128 else { return [] }

        // .npy 헤더 파싱: \x93NUMPY + version + header_len + header_str
        let magic = data.prefix(6)
        guard magic.count == 6, magic[0] == 0x93,
              magic[1] == 0x4E, magic[2] == 0x55 else { return [] }  // \x93NUM

        // 버전에 따라 헤더 길이 위치가 다름
        let majorVersion = data[6]
        let headerLen: Int
        let headerStart: Int

        if majorVersion == 1 {
            headerLen = Int(data[8]) | (Int(data[9]) << 8)
            headerStart = 10
        } else {
            headerLen = Int(data[8]) | (Int(data[9]) << 8) | (Int(data[10]) << 16) | (Int(data[11]) << 24)
            headerStart = 12
        }

        let dataStart = headerStart + headerLen
        guard dataStart < data.count else { return [] }

        let floatData = data.subdata(in: dataStart..<data.count)
        let result: [Float] = floatData.withUnsafeBytes { rawBuf in
            let floatBuf = rawBuf.bindMemory(to: Float.self)
            return Array(floatBuf)
        }
        return result
    }

    /// 임베딩 룩업: weights[tokenId] → [hiddenSize] 벡터
    private func embeddingLookup(weights: [Float], tokenId: Int, dim: Int) -> [Float] {
        let start = tokenId * dim
        guard start + dim <= weights.count else { return [Float](repeating: 0, count: dim) }
        return Array(weights[start..<(start + dim)])
    }

    // MARK: - ONNX 세션 로드

    private func loadOrtSessions(dir: URL) {
        do {
            ortEnv = try ORTEnv(loggingLevel: .warning)
            let opts = try ORTSessionOptions()
            try opts.setIntraOpNumThreads(4)

            // CoreML EP 비활성화 — 내부적으로 main thread dispatch해서
            // "should not be called on main thread" 경고 수백 개 + UI 블로킹 유발
            // CPU EP만 사용 (Apple Silicon에서도 충분히 빠름)
            print("[ONNXTTS] CPU EP 사용 (CoreML EP 비활성화 — main thread 블로킹 방지)")

            guard let env = ortEnv else { return }

            func loadSession(_ file: String, _ name: String, dir: URL, env: ORTEnv, opts: ORTSessionOptions) -> ORTSession? {
                let modelPath = dir.appendingPathComponent(file).path
                guard FileManager.default.fileExists(atPath: modelPath) else {
                    print("[ONNXTTS] ⚠️ \(name) 모델 없음: \(file)")
                    return nil
                }
                do {
                    let session = try ORTSession(env: env, modelPath: modelPath, sessionOptions: opts)
                    print("[ONNXTTS] ✅ \(name) 로드 완료")
                    return session
                } catch {
                    print("[ONNXTTS] ❌ \(name) 로드 실패: \(error.localizedDescription)")
                    return nil
                }
            }

            // T3: FP32 KV cache 우선 (INT8은 토큰 품질 저하 심함)
            t3PrefillSession = loadSession("t3_prefill_kv.onnx", "T3 Prefill (KV FP32)", dir: dir, env: env, opts: opts)
                ?? loadSession("t3_prefill_kv_int8.onnx", "T3 Prefill (KV+INT8)", dir: dir, env: env, opts: opts)
                ?? loadSession("t3_prefill.onnx", "T3 Prefill (legacy)", dir: dir, env: env, opts: opts)
            t3DecodeSession = loadSession("t3_decode_kv.onnx", "T3 Decode (KV FP32)", dir: dir, env: env, opts: opts)
                ?? loadSession("t3_decode_kv_int8.onnx", "T3 Decode (KV+INT8)", dir: dir, env: env, opts: opts)
            s3genEncSession = loadSession("s3gen_enc.onnx", "S3Gen Encoder", dir: dir, env: env, opts: opts)
            s3genCfmSession = loadSession("s3gen_cfm_int8.onnx", "S3Gen CFM (INT8)", dir: dir, env: env, opts: opts)
                ?? loadSession("s3gen_cfm.onnx", "S3Gen CFM", dir: dir, env: env, opts: opts)
            // hifigan_full.onnx = F0 + SourceModule + Decode 통합 (mel→magnitude+phase)
            hifiganSession = loadSession("hifigan_full.onnx", "HiFiGAN Full", dir: dir, env: env, opts: opts)
                ?? loadSession("hifigan.onnx", "HiFiGAN (legacy)", dir: dir, env: env, opts: opts)
            hifiganF0Session = loadSession("hifigan_f0.onnx", "HiFiGAN F0", dir: dir, env: env, opts: opts)
        } catch {
            print("[ONNXTTS] ❌ ORT 환경 생성 실패: \(error)")
        }
    }

    // MARK: - 공개 API

    func speak(_ text: String, characterName: String, emotion: AnimationState) {
        playerNode.stop()
        let cleaned = TextSanitizer.sanitize(text)
        guard !cleaned.isEmpty, isReady else {
            onSpeakComplete?(false)
            return
        }

        isSpeaking = true

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let success = await self.synthesize(text: cleaned, characterName: characterName, emotion: emotion)
            await MainActor.run {
                self.isSpeaking = false
                self.onSpeakComplete?(success)
            }
        }
    }

    private var currentSound: NSSound?

    func stop() {
        isSpeaking = false
        playerNode.stop()
        currentSound?.stop()
        currentSound = nil
    }

    // MARK: - 합성 파이프라인

    private func synthesize(text: String, characterName: String, emotion: AnimationState) async -> Bool {
        guard let voice = precomputedVoices[characterName] else {
            print("[ONNXTTS] ❌ \(characterName) pre-computed 데이터 없음")
            return false
        }

        // T3 온디바이스 추론 (BPE 토크나이저 수정 후 활성화 예정)
        print("[ONNXTTS] 🔄 합성 시작: '\(text.prefix(30))' (\(characterName))")

        // 1. BPE 토크나이징
        let textTokens = tokenize(text: text, languageID: "ko")
        print("[ONNXTTS] BPE 토큰 ID: \(textTokens.prefix(20))")
        guard !textTokens.isEmpty else {
            print("[ONNXTTS] ❌ 토크나이징 실패")
            return false
        }
        print("[ONNXTTS] 텍스트 토큰: \(textTokens.count)개")

        // 2. T3 추론 → speech tokens
        let speechTokens: [Int64]
        do {
            speechTokens = try runT3Inference(textTokens: textTokens, voice: voice)
        } catch {
            print("[ONNXTTS] ❌ T3 추론 실패: \(error)")
            return false
        }
        print("[ONNXTTS] speech tokens: \(speechTokens.count)개")

        // 3. S3Gen 추론 → mel spectrogram
        let mel: Tensor
        do {
            mel = try runS3GenInference(speechTokens: speechTokens, voice: voice)
        } catch {
            print("[ONNXTTS] ❌ S3Gen 추론 실패: \(error)")
            return false
        }
        print("[ONNXTTS] mel spectrogram: \(mel.shape)")

        // 4. HiFiGAN 추론 → PCM
        let pcm: [Float]
        do {
            pcm = try runHiFiGANInference(mel: mel)
        } catch {
            print("[ONNXTTS] ❌ HiFiGAN 추론 실패: \(error)")
            return false
        }
        print("[ONNXTTS] ✅ PCM 생성: \(pcm.count) samples (\(Double(pcm.count)/24000.0)초)")

        // 5. 재생
        await playPCM(pcm)
        return true
    }

    // MARK: - 텐서 헬퍼

    struct Tensor {
        var data: [Float]
        var shape: [Int]

        var count: Int { data.count }

        func value(at indices: [Int]) -> Float {
            var offset = 0
            var s = 1
            for i in Swift.stride(from: shape.count - 1, through: 0, by: -1) {
                offset += indices[i] * s
                s *= shape[i]
            }
            return data[offset]
        }
    }

    private func makeORTValue(floats: [Float], shape: [Int]) throws -> ORTValue {
        let byteCount = floats.count * MemoryLayout<Float>.size
        let mutableData = NSMutableData(bytes: floats, length: byteCount)
        return try ORTValue(
            tensorData: mutableData,
            elementType: .float,
            shape: shape.map { NSNumber(value: $0) }
        )
    }

    private func makeORTValue(int64s: [Int64], shape: [Int]) throws -> ORTValue {
        let byteCount = int64s.count * MemoryLayout<Int64>.size
        let mutableData = NSMutableData(bytes: int64s, length: byteCount)
        return try ORTValue(
            tensorData: mutableData,
            elementType: .int64,
            shape: shape.map { NSNumber(value: $0) }
        )
    }

    private func extractFloats(from value: ORTValue) throws -> [Float] {
        let nsData = try value.tensorData()
        let length = nsData.length / MemoryLayout<Float>.size
        var result = [Float](repeating: 0, count: length)
        nsData.getBytes(&result, length: nsData.length)
        return result
    }

    /// bool 텐서를 Float 배열로 변환 (S3Gen mel_mask용)
    /// bool: 1바이트/원소(0x00=false, 0x01=true) → Float 0.0/1.0
    private func extractBoolsAsFloats(from value: ORTValue) throws -> [Float] {
        let nsData = try value.tensorData()
        let count = nsData.length  // bool은 1바이트/원소
        var bytes = [UInt8](repeating: 0, count: count)
        nsData.getBytes(&bytes, length: count)
        return bytes.map { $0 != 0 ? Float(1.0) : Float(0.0) }
    }

    // MARK: - T3 추론 (텍스트 → 음성 토큰) — KV cache 기반 O(n) 추론

    private func runT3Inference(textTokens: [Int], voice: PrecomputedVoice) throws -> [Int64] {
        guard let prefillSession = t3PrefillSession else {
            throw NSError(domain: "ONNXTTS", code: -1, userInfo: [NSLocalizedDescriptionKey: "T3 prefill 세션 없음"])
        }
        guard !textEmbWeights.isEmpty, !speechEmbWeights.isEmpty else {
            throw NSError(domain: "ONNXTTS", code: -1, userInfo: [NSLocalizedDescriptionKey: "임베딩 가중치 미로드"])
        }

        let H = hiddenSize  // 1024

        // ── 1. T3 conditioning (pre-computed: spkr_enc + perceiver) ──
        // Python 원본: inputs_embeds = [cond_embeds] + [text_emb + text_pos] + [BOS]
        let condLen = voice.t3CondEmbedsShape.first ?? 0
        let textLen = textTokens.count

        // t3_cond_embeds가 있으면 사용 (perceiver 포함), 없으면 legacy (spkr_enc만)
        var prefillEmbeds: [Float]
        let totalPrefillLen: Int

        if condLen > 0 && voice.t3CondEmbeds.count == condLen * H {
            // ── 정상 경로: [t3_cond_embeds(34×1024)] + [text_emb + text_pos] + [BOS] ──
            totalPrefillLen = condLen + textLen + 1  // +1 for BOS token
            prefillEmbeds = [Float](repeating: 0, count: totalPrefillLen * H)

            // 1) conditioning (spkr + perceiver)
            prefillEmbeds.replaceSubrange(0..<(condLen * H), with: voice.t3CondEmbeds)

            // 2) text embeddings
            for (i, tokenId) in textTokens.enumerated() {
                let tokenEmb = embeddingLookup(weights: textEmbWeights, tokenId: tokenId, dim: H)
                let posEmb = embeddingLookup(weights: textPosEmbWeights, tokenId: i, dim: H)
                let offset = (condLen + i) * H
                for j in 0..<H { prefillEmbeds[offset + j] = tokenEmb[j] + posEmb[j] }
            }

            // 3) BOS token: speech_emb[startSpeechToken] + speech_pos_emb[0]
            let bosEmb = embeddingLookup(weights: speechEmbWeights, tokenId: startSpeechToken, dim: H)
            let bosPos = embeddingLookup(weights: speechPosEmbWeights, tokenId: 0, dim: H)
            let bosOffset = (condLen + textLen) * H
            for j in 0..<H { prefillEmbeds[bosOffset + j] = bosEmb[j] + bosPos[j] }

        } else {
            // ── Legacy 경로: [spkr_enc(ve)] + [text_emb + text_pos] ──
            var condEmbed = [Float](repeating: 0, count: H)
            if !spkrEncWeight.isEmpty && voice.veEmbed.count == 256 {
                for i in 0..<H {
                    var sum = spkrEncBias.count > i ? spkrEncBias[i] : 0
                    for j in 0..<256 { sum += spkrEncWeight[i * 256 + j] * voice.veEmbed[j] }
                    condEmbed[i] = sum
                }
            }
            totalPrefillLen = 1 + textLen
            prefillEmbeds = [Float](repeating: 0, count: totalPrefillLen * H)
            prefillEmbeds.replaceSubrange(0..<H, with: condEmbed)
            for (i, tokenId) in textTokens.enumerated() {
                let tokenEmb = embeddingLookup(weights: textEmbWeights, tokenId: tokenId, dim: H)
                let posEmb = embeddingLookup(weights: textPosEmbWeights, tokenId: i, dim: H)
                let offset = (1 + i) * H
                for j in 0..<H { prefillEmbeds[offset + j] = tokenEmb[j] + posEmb[j] }
            }
        }

        // ── 3. KV cache 출력 이름 생성 ──
        var kvOutNames = [String]()
        for i in 0..<nLayers {
            kvOutNames.append("new_key_\(i)")
            kvOutNames.append("new_val_\(i)")
        }
        let allOutputNames = Set(["logits"] + kvOutNames)

        // ── 4. CFG Prefill (batch_size=2) ──
        // [0] = conditioned (텍스트 포함), [1] = unconditioned (텍스트 zero)
        let cfgWeight: Float = 0.5
        var uncondEmbeds = [Float](repeating: 0, count: totalPrefillLen * H)
        // uncond: conditioning + BOS는 동일, text 부분만 zero
        if condLen > 0 {
            uncondEmbeds.replaceSubrange(0..<(condLen * H), with: voice.t3CondEmbeds)
            // text 부분은 이미 0
            let bosEmb = embeddingLookup(weights: speechEmbWeights, tokenId: startSpeechToken, dim: H)
            let bosPos = embeddingLookup(weights: speechPosEmbWeights, tokenId: 0, dim: H)
            let bosOffset = (condLen + textLen) * H
            for j in 0..<H { uncondEmbeds[bosOffset + j] = bosEmb[j] + bosPos[j] }
        }

        // batch_size=2: [cond; uncond]
        var batchEmbeds = [Float](repeating: 0, count: 2 * totalPrefillLen * H)
        batchEmbeds.replaceSubrange(0..<(totalPrefillLen * H), with: prefillEmbeds)
        batchEmbeds.replaceSubrange((totalPrefillLen * H)..<(2 * totalPrefillLen * H), with: uncondEmbeds)

        let embedValue = try makeORTValue(floats: batchEmbeds, shape: [2, totalPrefillLen, H])
        let prefillOutputs = try prefillSession.run(
            withInputs: ["inputs_embeds": embedValue],
            outputNames: allOutputNames,
            runOptions: nil
        )

        guard let logitsValue = prefillOutputs["logits"] else {
            throw NSError(domain: "ONNXTTS", code: -2, userInfo: [NSLocalizedDescriptionKey: "Prefill logits 없음"])
        }

        let allLogits = try extractFloats(from: logitsValue)
        let logitsInfo = try logitsValue.tensorTypeAndShapeInfo()
        let logitsShape = logitsInfo.shape.map { $0.intValue }  // [2, seq, vocabSize]
        let vocabSize = logitsShape.last ?? speechVocabSize
        let batchSize = logitsShape.first ?? 1
        let seqLen = logitsShape.count >= 3 ? logitsShape[1] : totalPrefillLen

        print("[ONNXTTS] CFG logits shape: \(logitsShape), total=\(allLogits.count)")

        // CFG: cond + cfg_weight * (cond - uncond) from last position
        var cfgLogits: [Float]

        if batchSize >= 2 {
            // batch=2: [batch0=cond, batch1=uncond]
            let condOffset = (seqLen - 1) * vocabSize                        // batch 0, last pos
            let uncondOffset = seqLen * vocabSize + (seqLen - 1) * vocabSize  // batch 1, last pos

            cfgLogits = [Float](repeating: 0, count: vocabSize)
            for i in 0..<vocabSize {
                let c = allLogits[condOffset + i]
                let u = allLogits[uncondOffset + i]
                cfgLogits[i] = c + cfgWeight * (c - u)
            }
            // 디버그: CFG 효과 확인
            let topCond = (0..<vocabSize).max(by: { allLogits[condOffset + $0] < allLogits[condOffset + $1] })!
            let topCfg = (0..<vocabSize).max(by: { cfgLogits[$0] < cfgLogits[$1] })!
            print("[ONNXTTS] CFG 디버그: cond_top=\(topCond), cfg_top=\(topCfg)")
        } else {
            // batch=1 폴백 (CFG 미적용)
            print("[ONNXTTS] ⚠️ batch=\(batchSize), CFG 미적용!")
            let lastLogitOffset = (seqLen - 1) * vocabSize
            cfgLogits = Array(allLogits[lastLogitOffset..<(lastLogitOffset + vocabSize)])
        }

        let firstToken = sampleTopP(logits: cfgLogits, topP: 0.85, temperature: 0.8)

        var speechTokens: [Int64] = [Int64(firstToken)]
        print("[ONNXTTS] T3 prefill 완료 (seq=\(totalPrefillLen)), 첫 speech 토큰: \(firstToken)")

        // ── 5. KV cache 추출 ──
        var kvCache = [String: ORTValue]()
        for kvName in kvOutNames {
            guard let kvValue = prefillOutputs[kvName] else {
                print("[ONNXTTS] ⚠️ KV cache \(kvName) 없음 — legacy 모델일 수 있음")
                // KV cache 없으면 legacy 방식으로 폴백 (이 함수 끝에서 반환)
                print("[ONNXTTS] T3 완료 (prefill only): \(speechTokens.count)개 speech tokens")
                return speechTokens
            }
            let inName = kvName.replacingOccurrences(of: "new_", with: "past_")
            kvCache[inName] = kvValue
        }

        // ── 6. Decode loop (KV cache 기반 — O(n), 스텝당 ~0.01초) ──
        guard let decodeSession = t3DecodeSession else {
            // decode 세션 없으면 prefill 결과만 반환
            print("[ONNXTTS] ⚠️ T3 decode 세션 없음 — prefill 토큰만 반환")
            return speechTokens
        }

        // ── Alignment heuristics (alignment_stream_analyzer 대체) ──
        // 텍스트 토큰당 ~10개 speech token 비례 + 상한 300
        let minSpeechTokens = max(textLen * 3, 10)   // EOS 억제 최소 구간
        let maxSteps = min(textLen * 12, 300)         // 텍스트 비례 최대

        for step in 0..<maxSteps {
            guard isSpeaking else { break }

            // CFG decode: batch_size=2 (cond=uncond 동일, KV cache가 차이를 만듦)
            let tok = Int(speechTokens.last!)
            let tokEmb = embeddingLookup(weights: speechEmbWeights, tokenId: tok, dim: H)
            let posEmb = embeddingLookup(weights: speechPosEmbWeights, tokenId: step + 1, dim: H)
            var singleEmbed = [Float](repeating: 0, count: H)
            for j in 0..<H { singleEmbed[j] = tokEmb[j] + posEmb[j] }

            // batch_size=2: 동일한 임베딩 2개
            var batchEmbed = [Float](repeating: 0, count: 2 * H)
            batchEmbed.replaceSubrange(0..<H, with: singleEmbed)
            batchEmbed.replaceSubrange(H..<(2*H), with: singleEmbed)
            let tokenValue = try makeORTValue(floats: batchEmbed, shape: [2, 1, H])

            var decodeInputs: [String: ORTValue] = ["token_embed": tokenValue]
            for (k, v) in kvCache { decodeInputs[k] = v }

            let decodeOutputs = try decodeSession.run(
                withInputs: decodeInputs,
                outputNames: allOutputNames,
                runOptions: nil
            )

            guard let stepLogitsValue = decodeOutputs["logits"] else { break }
            let stepLogits = try extractFloats(from: stepLogitsValue)

            // logits: [2, 1, vocabSize] → CFG 결합
            guard stepLogits.count >= 2 * vocabSize else { break }
            var tokenLogits = [Float](repeating: 0, count: vocabSize)
            for i in 0..<vocabSize {
                let c = stepLogits[i]                    // batch 0 (cond)
                let u = stepLogits[vocabSize + i]        // batch 1 (uncond)
                tokenLogits[i] = c + cfgWeight * (c - u)
            }

            // ── [Alignment 1] EOS 조기 억제 ──
            // 텍스트를 다 읽기 전에 stop token이 나오면 무시
            if speechTokens.count < minSpeechTokens {
                tokenLogits[stopSpeechToken] = -Float.infinity
            }

            // ── [Alignment 3] Repetition penalty ──
            // 최근 8개 토큰의 확률을 낮춰서 반복 방지
            let recentWindow = speechTokens.suffix(8)
            let repPenalty: Float = 1.3
            for recentTok in Set(recentWindow) {
                let idx = Int(recentTok)
                if idx < tokenLogits.count {
                    if tokenLogits[idx] > 0 {
                        tokenLogits[idx] /= repPenalty
                    } else {
                        tokenLogits[idx] *= repPenalty
                    }
                }
            }

            let nextToken = sampleTopP(logits: tokenLogits, topP: 0.85, temperature: 0.8)
            if nextToken == stopSpeechToken {
                print("[ONNXTTS] T3 stop token at step \(step)")
                break
            }
            speechTokens.append(Int64(nextToken))

            // ── [Alignment 2] 반복 토큰 감지 → 강제 종료 ──
            if speechTokens.count >= 3 {
                let last3 = speechTokens.suffix(3)
                if Set(last3).count == 1 {
                    print("[ONNXTTS] ⚠️ 반복 토큰 감지 (\(last3.first!)) → 강제 종료")
                    break
                }
            }

            // KV cache 업데이트 (in-place swap)
            for kvName in kvOutNames {
                if let newKV = decodeOutputs[kvName] {
                    let inName = kvName.replacingOccurrences(of: "new_", with: "past_")
                    kvCache[inName] = newKV
                }
            }

            if step % 50 == 0 {
                print("[ONNXTTS] T3 decode step \(step), tokens: \(speechTokens.count)")
            }
        }

        print("[ONNXTTS] T3 완료: \(speechTokens.count)개 speech tokens (KV cache, max=\(maxSteps))")
        return speechTokens
    }

    // MARK: - Top-p (nucleus) 샘플링

    private func sampleTopP(logits: [Float], topP: Float, temperature: Float) -> Int {
        let scaledLogits = logits.map { $0 / max(temperature, 0.01) }
        let maxLogit = scaledLogits.max() ?? 0
        let exps = scaledLogits.map { exp($0 - maxLogit) }
        let sumExp = exps.reduce(0, +)
        let probs = exps.map { $0 / sumExp }

        // 확률순 정렬
        let indexed = probs.enumerated().sorted { $0.element > $1.element }

        var cumProb: Float = 0
        var candidates: [(Int, Float)] = []
        for (idx, prob) in indexed {
            cumProb += prob
            candidates.append((idx, prob))
            if cumProb >= topP { break }
        }

        // 후보 중 랜덤 샘플링
        let totalProb = candidates.reduce(Float(0)) { $0 + $1.1 }
        var random = Float.random(in: 0..<totalProb)
        for (idx, prob) in candidates {
            random -= prob
            if random <= 0 { return idx }
        }
        return candidates.last?.0 ?? 0
    }

    // MARK: - S3Gen 추론 (토큰 → 멜 스펙트로그램)

    private func runS3GenInference(speechTokens: [Int64], voice: PrecomputedVoice) throws -> Tensor {
        guard let encSession = s3genEncSession,
              let cfmSession = s3genCfmSession else {
            throw NSError(domain: "ONNXTTS", code: -3, userInfo: [NSLocalizedDescriptionKey: "S3Gen 세션 없음"])
        }

        let tokenLen = speechTokens.count
        let promptLen = voice.promptTokens.count
        let promptFeatT = voice.promptFeatShape[0]

        // S3Gen Encoder 입력
        let tokenValue = try makeORTValue(int64s: speechTokens, shape: [1, tokenLen])
        let tokenLenValue = try makeORTValue(int64s: [Int64(tokenLen)], shape: [1])
        let promptTokenValue = try makeORTValue(int64s: voice.promptTokens, shape: [1, promptLen])
        let promptTokenLenValue = try makeORTValue(int64s: [Int64(promptLen)], shape: [1])
        let promptFeatValue = try makeORTValue(floats: voice.promptFeat, shape: [1, promptFeatT, 80])
        let embeddingValue = try makeORTValue(floats: voice.xvector, shape: [1, voice.xvector.count])

        // S3Gen Encoder 실행
        let encOutputs = try encSession.run(
            withInputs: [
                "token": tokenValue,
                "token_len": tokenLenValue,
                "prompt_token": promptTokenValue,
                "prompt_token_len": promptTokenLenValue,
                "prompt_feat": promptFeatValue,
                "embedding": embeddingValue,
            ],
            outputNames: Set(["mu", "conds", "spks"]),  // mel_mask는 bool 타입이라 ORT Swift에서 읽기 불가 → 직접 생성
            runOptions: nil
        )

        guard let muValue = encOutputs["mu"],
              let condsValue = encOutputs["conds"],
              let spksValue = encOutputs["spks"] else {
            throw NSError(domain: "ONNXTTS", code: -4, userInfo: [NSLocalizedDescriptionKey: "S3Gen Encoder 출력 누락"])
        }

        let muInfo = try muValue.tensorTypeAndShapeInfo()
        let muShape = muInfo.shape.map { $0.intValue }

        let mu = try extractFloats(from: muValue)

        // mel_mask는 bool 타입 — ORT Swift 바인딩이 bool tensorData()를 지원 안 함
        // mel_mask는 항상 모든 프레임이 유효(true)이므로 1.0으로 직접 생성
        let melT = muShape[2]
        let mask = [Float](repeating: 1.0, count: melT)

        let conds = try extractFloats(from: condsValue)
        let spks = try extractFloats(from: spksValue)

        print("[ONNXTTS] S3Gen Encoder: mu=\(muShape), melT=\(melT)")

        // CFM ODE Loop (Euler method, 10 steps)
        let nSteps = 10
        var x = (0..<(80 * melT)).map { _ in Float.random(in: -1...1) * 0.1 }

        for step in 0..<nSteps {
            let t0 = Float(step) / Float(nSteps)
            let t1 = Float(step + 1) / Float(nSteps)

            let xValue = try makeORTValue(floats: x, shape: [1, 80, melT])
            let maskVal = try makeORTValue(floats: mask, shape: [1, 1, melT])
            let muVal = try makeORTValue(floats: mu, shape: [1, 80, melT])
            let tValue = try makeORTValue(floats: [t0], shape: [1])
            let spksVal = try makeORTValue(floats: spks, shape: [1, spks.count])
            let condVal = try makeORTValue(floats: conds, shape: [1, 80, melT])

            let cfmOutputs = try cfmSession.run(
                withInputs: [
                    "x": xValue,
                    "mask": maskVal,
                    "mu": muVal,
                    "t": tValue,
                    "spks": spksVal,
                    "cond": condVal,
                ],
                outputNames: Set(["dxdt"]),
                runOptions: nil
            )

            guard let dxdtValue = cfmOutputs["dxdt"] else { break }
            let dxdt = try extractFloats(from: dxdtValue)

            let dt = t1 - t0
            for i in 0..<x.count {
                x[i] += dt * dxdt[i]
            }
        }

        print("[ONNXTTS] CFM ODE 완료 (10 steps)")

        return Tensor(data: x, shape: [1, 80, melT])
    }

    // MARK: - HiFiGAN 추론 (멜 → PCM)

    private func runHiFiGANInference(mel: Tensor) throws -> [Float] {
        guard let hifiSession = hifiganSession else {
            throw NSError(domain: "ONNXTTS", code: -5, userInfo: [NSLocalizedDescriptionKey: "HiFiGAN 세션 없음"])
        }

        // hifigan_full.onnx: mel → magnitude + phase (F0 + SourceModule + Decode 통합)
        let melValue = try makeORTValue(floats: mel.data, shape: mel.shape)

        let hifiOutputs = try hifiSession.run(
            withInputs: ["mel": melValue],
            outputNames: Set(["magnitude", "phase"]),
            runOptions: nil
        )

        guard let magValue = hifiOutputs["magnitude"],
              let phaseValue = hifiOutputs["phase"] else {
            throw NSError(domain: "ONNXTTS", code: -7, userInfo: [NSLocalizedDescriptionKey: "HiFiGAN 출력 없음"])
        }

        let magnitude = try extractFloats(from: magValue)
        let phaseData = try extractFloats(from: phaseValue)
        let magInfo = try magValue.tensorTypeAndShapeInfo()
        let magShape = magInfo.shape.map { $0.intValue }  // [B, n_fft/2+1, T_stft]

        print("[ONNXTTS] HiFiGAN: mag=\(magShape)")

        // 4. ISTFT (n_fft=16, hop=4)
        let nFFT = 16
        let hopLen = 4
        let nBins = nFFT / 2 + 1  // 9
        let nPhase = nFFT / 2      // 8
        let nFrames = magShape[2]

        let pcm = istft(magnitude: magnitude, phase: phaseData,
                        nBins: nBins, nPhase: nPhase, nFrames: nFrames,
                        nFFT: nFFT, hopLen: hopLen)

        return pcm
    }

    // MARK: - ISTFT (vDSP, n_fft=16, hop=4)

    private func istft(magnitude: [Float], phase: [Float],
                       nBins: Int, nPhase: Int, nFrames: Int,
                       nFFT: Int, hopLen: Int) -> [Float] {

        let audioLen = (nFrames - 1) * hopLen + nFFT
        var output = [Float](repeating: 0, count: audioLen)
        var windowSum = [Float](repeating: 0, count: audioLen)

        // Periodic Hann 윈도우 (torch.hann_window 호환 — nFFT-1이 아니라 nFFT로 나누기!)
        let window = (0..<nFFT).map { n -> Float in
            0.5 * (1 - cos(2 * Float.pi * Float(n) / Float(nFFT)))
        }

        for frame in 0..<nFrames {
            // magnitude → real, imag 변환
            var real = [Float](repeating: 0, count: nFFT)
            var imag = [Float](repeating: 0, count: nFFT)

            for k in 0..<nBins {
                let mag = min(magnitude[k * nFrames + frame], 1e2)  // clip max=100 (torch.clip)
                let ph = phase[k * nFrames + frame]
                real[k] = mag * cos(ph)
                imag[k] = mag * sin(ph)
            }

            // 양측 스펙트럼 복원 (대칭)
            for k in 1..<(nFFT / 2) {
                real[nFFT - k] = real[k]
                imag[nFFT - k] = -imag[k]
            }

            // IDFT (n_fft=16이므로 직접 계산)
            var samples = [Float](repeating: 0, count: nFFT)
            for n in 0..<nFFT {
                var sum: Float = 0
                for k in 0..<nFFT {
                    let angle = 2 * Float.pi * Float(k) * Float(n) / Float(nFFT)
                    sum += real[k] * cos(angle) - imag[k] * sin(angle)
                }
                samples[n] = sum / Float(nFFT)
            }

            // 윈도우 적용 + overlap-add
            let offset = frame * hopLen
            for n in 0..<nFFT where offset + n < audioLen {
                output[offset + n] += samples[n] * window[n]
                windowSum[offset + n] += window[n] * window[n]
            }
        }

        // 윈도우 정규화
        for i in 0..<audioLen {
            if windowSum[i] > 1e-8 {
                output[i] /= windowSum[i]
            }
        }

        return output
    }

    // MARK: - 한글 자모 분해 + BPE 토크나이징

    func tokenize(text: String, languageID: String) -> [Int] {
        // Python 동일 로직: lowercase → NFKD → korean_normalize → [lang] prefix → [SPACE]
        var processed = text.lowercased()

        // NFKD 정규화 (한글 음절 → 자모 분해)
        processed = processed.precomposedStringWithCompatibilityMapping  // 먼저 NFC
        processed = processed.decomposedStringWithCompatibilityMapping   // 그 다음 NFKD

        switch languageID {
        case "ko": processed = koreanNormalize(processed)
        default: break
        }

        // [lang] prefix + [SPACE] 치환
        let langPrefix = "[\(languageID)]"
        let withLang = langPrefix + processed
        let spaceReplaced = withLang.replacingOccurrences(of: " ", with: "[SPACE]")

        let ids = bpeEncode(text: spaceReplaced)
        return [startTextToken] + ids + [stopTextToken]
    }

    private func koreanNormalize(_ text: String) -> String {
        // NFKD 이후 자모가 grapheme cluster로 합쳐질 수 있으므로
        // Unicode scalar 단위로 처리
        var result = ""
        for scalar in text.unicodeScalars {
            let value = scalar.value
            if value >= 0xAC00 && value <= 0xD7A3 {
                // 조합형 한글 → 자모 분해 (NFKD가 안 풀었을 경우 대비)
                let base = Int(value - 0xAC00)
                let initial = base / (21 * 28)
                let medial = (base % (21 * 28)) / 28
                let final_ = base % 28
                result.append(Character(UnicodeScalar(0x1100 + initial)!))
                result.append(Character(UnicodeScalar(0x1161 + medial)!))
                if final_ > 0 {
                    result.append(Character(UnicodeScalar(0x11A7 + final_)!))
                }
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    private func bpeEncode(text: String) -> [Int] {
        guard !bpeVocab.isEmpty else { return [] }

        let specialPattern = try? NSRegularExpression(pattern: "\\[[^\\]]+\\]")
        let nsText = text as NSString
        var lastEnd = 0
        var segments: [(String, Bool)] = []

        if let pattern = specialPattern {
            let matches = pattern.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                let range = match.range
                if range.location > lastEnd {
                    segments.append((nsText.substring(with: NSRange(location: lastEnd, length: range.location - lastEnd)), false))
                }
                segments.append((nsText.substring(with: range), true))
                lastEnd = range.location + range.length
            }
        }
        if lastEnd < nsText.length {
            segments.append((nsText.substring(from: lastEnd), false))
        }
        if segments.isEmpty { segments = [(text, false)] }

        var result: [Int] = []
        for (segment, isSpecial) in segments {
            if isSpecial {
                if let id = bpeVocab[segment] { result.append(id) }
            } else {
                result.append(contentsOf: bpeEncodeSegment(segment))
            }
        }
        return result
    }

    private func bpeEncodeSegment(_ text: String) -> [Int] {
        guard !text.isEmpty else { return [] }
        // Python HuggingFace tokenizer와 동일: Unicode scalar 단위 character-level 토큰화
        // Swift의 Character는 grapheme cluster(자모가 합쳐진 음절)이므로
        // 반드시 unicodeScalars 단위로 분리해야 자모 개별 토큰이 나옴
        let symbols = text.unicodeScalars.map { String($0) }
        /*  BPE merge 원본 (필요 시 복원):
        var symbols = text.map { String($0) }
        var changed = true
        while changed && !bpeMerges.isEmpty {
            changed = false
            var i = 0
            while i < symbols.count - 1 {
                let pair = (symbols[i], symbols[i + 1])
                if bpeMerges.firstIndex(where: { $0 == pair }) != nil {
                    symbols[i] = pair.0 + pair.1
                    symbols.remove(at: i + 1)
                    changed = true
                } else {
                    i += 1
                }
            }
        }
        */
        return symbols.compactMap { bpeVocab[$0] }
    }

    // MARK: - 레퍼런스 오디오 찾기

    private func findReferenceAudio(characterName: String) -> String? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let dirs = [
            Bundle.main.resourceURL?.appendingPathComponent("ReferenceAudio"),
            appSupport?.appendingPathComponent("MyTeam/ReferenceAudio")
        ].compactMap { $0 }

        for dir in dirs {
            for ext in ["wav", "mp3"] {
                let url = dir.appendingPathComponent("\(characterName)_reference.\(ext)")
                if FileManager.default.fileExists(atPath: url.path) { return url.path }
            }
        }
        return nil
    }

    // MARK: - 멜 스펙트로그램 (Swift/Accelerate)

    func computeMelSpectrogram(
        samples: [Float], sampleRate: Int = 16000,
        nFFT: Int = 400, hopLength: Int = 160, nMels: Int = 40
    ) -> [[Float]] {
        guard samples.count >= nFFT else { return [] }

        let window = hanningWindow(size: nFFT)
        var frames: [[Float]] = []

        var start = 0
        while start + nFFT <= samples.count {
            let frame = Array(samples[start..<(start + nFFT)])
            var windowed = [Float](repeating: 0, count: nFFT)
            vDSP_vmul(frame, 1, window, 1, &windowed, 1, vDSP_Length(nFFT))
            let mag = computeFFTMagnitude(windowed, nFFT: nFFT)
            let melFrame = applyMelFilters(mag, sampleRate: sampleRate, nFFT: nFFT, nMels: nMels)
            frames.append(melFrame)
            start += hopLength
        }
        return frames
    }

    private func hanningWindow(size: Int) -> [Float] {
        (0..<size).map { 0.5 * (1 - cos(2 * Float.pi * Float($0) / Float(size - 1))) }
    }

    private func computeFFTMagnitude(_ signal: [Float], nFFT: Int) -> [Float] {
        let halfN = nFFT / 2 + 1
        var real = signal
        var imag = [Float](repeating: 0, count: nFFT)

        let log2N = vDSP_Length(log2(Double(nFFT)))
        guard let fftSetup = vDSP_create_fftsetup(log2N, FFTRadix(kFFTRadix2)) else {
            return [Float](repeating: 0, count: halfN)
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        real.withUnsafeMutableBufferPointer { realBuf in
            imag.withUnsafeMutableBufferPointer { imagBuf in
                var splitComplex = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                signal.withUnsafeBytes { ptr in
                    let complexPtr = ptr.bindMemory(to: DSPComplex.self)
                    vDSP_ctoz(complexPtr.baseAddress!, 2, &splitComplex, 1, vDSP_Length(nFFT / 2))
                }
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2N, FFTDirection(kFFTDirection_Forward))
            }
        }

        var magnitudes = [Float](repeating: 0, count: halfN)
        real.withUnsafeMutableBufferPointer { realBuf in
            imag.withUnsafeMutableBufferPointer { imagBuf in
                var splitComplex = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfN))
            }
        }
        return magnitudes
    }

    private func applyMelFilters(_ powerSpectrum: [Float], sampleRate: Int, nFFT: Int, nMels: Int) -> [Float] {
        let filters = createMelFilterBank(sampleRate: sampleRate, nFFT: nFFT, nMels: nMels)
        return filters.map { filter in
            var sum: Float = 0
            vDSP_dotpr(powerSpectrum, 1, filter, 1, &sum, vDSP_Length(min(powerSpectrum.count, filter.count)))
            return max(sum, 1e-10)
        }
    }

    private func createMelFilterBank(sampleRate: Int, nFFT: Int, nMels: Int) -> [[Float]] {
        let fMax = Float(sampleRate) / 2
        func hzToMel(_ hz: Float) -> Float { 2595 * log10(1 + hz / 700) }
        func melToHz(_ mel: Float) -> Float { 700 * (pow(10, mel / 2595) - 1) }

        let melMin = hzToMel(0)
        let melMax = hzToMel(fMax)
        let melPoints = (0...(nMels + 1)).map { melToHz(melMin + Float($0) * (melMax - melMin) / Float(nMels + 1)) }
        let freqBins = (0...nFFT / 2).map { Float($0) * Float(sampleRate) / Float(nFFT) }
        let halfN = nFFT / 2 + 1

        return (0..<nMels).map { m in
            var filter = [Float](repeating: 0, count: halfN)
            let (lower, center, upper) = (melPoints[m], melPoints[m + 1], melPoints[m + 2])
            for k in 0..<halfN {
                let f = freqBins[k]
                if f >= lower && f <= center { filter[k] = (f - lower) / (center - lower) }
                else if f > center && f <= upper { filter[k] = (upper - f) / (upper - center) }
            }
            return filter
        }
    }

    // MARK: - PCM 재생

    private func playPCM(_ samples: [Float]) async {
        guard !samples.isEmpty else { return }

        // PCM float32 → WAV 데이터 생성 → AVAudioPlayer로 재생
        // (AVAudioEngine은 Mac mini에서 무음이므로 우회)
        let sampleRate: UInt32 = 24000
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let bytesPerSample = bitsPerSample / 8
        let dataSize = UInt32(samples.count * Int(bytesPerSample))

        var wavData = Data()
        // RIFF header
        wavData.append(contentsOf: "RIFF".utf8)
        var chunkSize = UInt32(36 + dataSize)
        wavData.append(Data(bytes: &chunkSize, count: 4))
        wavData.append(contentsOf: "WAVE".utf8)
        // fmt sub-chunk
        wavData.append(contentsOf: "fmt ".utf8)
        var subchunk1Size: UInt32 = 16
        wavData.append(Data(bytes: &subchunk1Size, count: 4))
        var audioFormat: UInt16 = 1  // PCM
        wavData.append(Data(bytes: &audioFormat, count: 2))
        var channels = numChannels
        wavData.append(Data(bytes: &channels, count: 2))
        var sr = sampleRate
        wavData.append(Data(bytes: &sr, count: 4))
        var byteRate = sampleRate * UInt32(numChannels) * UInt32(bytesPerSample)
        wavData.append(Data(bytes: &byteRate, count: 4))
        var blockAlign = numChannels * bytesPerSample
        wavData.append(Data(bytes: &blockAlign, count: 2))
        var bps = bitsPerSample
        wavData.append(Data(bytes: &bps, count: 2))
        // data sub-chunk
        wavData.append(contentsOf: "data".utf8)
        var ds = dataSize
        wavData.append(Data(bytes: &ds, count: 4))
        // PCM samples (float32 → int16)
        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            var int16Val = Int16(clamped * 32767)
            wavData.append(Data(bytes: &int16Val, count: 2))
        }

        // 임시 WAV 파일로 저장 → NSSound로 재생 (Mac mini 호환)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("onnxtts_\(UUID().uuidString).wav")
        do {
            try wavData.write(to: tempURL)
            let sound = NSSound(contentsOf: tempURL, byReference: false)
            self.currentSound = sound
            _ = await MainActor.run { sound?.play() }
            let dur = Double(samples.count) / Double(sampleRate)
            try? await Task.sleep(nanoseconds: UInt64(dur * 1_000_000_000))
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            print("[ONNXTTS] ❌ PCM 재생 실패: \(error)")
        }
    }
}
