import Foundation
@preconcurrency import AVFoundation
import MLX
import Qwen3TTS

// MARK: - Qwen3TTSService
// Chatterbox (T3 + S3Gen + HiFiGAN) 파이프라인을 Qwen3-TTS 1.7B MLX 4bit으로 교체
// 인터페이스는 기존 MLXInferenceService와 동일하게 유지 (SpeechManager 호환)
//
// 영구 설계 원칙:
//   - 새 요청 시 이전 추론 즉시 cancel() (G-Stack 직렬화 금지)
//   - Apple TTS 사용 금지 (폴백 포함)
//   - 출력: 24kHz Float32 PCM Data 스트림

@globalActor
public actor Qwen3TTSActor {
    public static let shared = Qwen3TTSActor()
}

@Qwen3TTSActor
final class Qwen3TTSService {
    nonisolated static let shared = Qwen3TTSService()
    nonisolated static let voiceCloneDefaultsKey = "MyTeam.TTS.useQwenVoiceClone"

    private var ttsModel: Qwen3TTSModel?
    private var isLoading = false

    // 캐릭터별 레퍼런스 오디오 캐시 (24kHz Float32)
    private var voiceCache: [String: [Float]] = [:]

    // 즉시 취소용 현재 태스크
    private var speechTask: Task<Void, Error>?

    // MARK: - Fallback Policy

    enum TTSFallbackReason: String {
        case referenceNotFound = "reference_not_found"
        case voiceCloneDisabled = "clone_disabled"
        case synthesisTimeout = "synthesis_timeout"
        case qualityGateFailed = "quality_gate_failed"
    }

    /// 캐릭터별 연속 voice clone 실패 횟수 — 3회 도달 시 세션 동안 자동 비활성
    private var consecutiveFailures: [String: Int] = [:]
    private var sessionDisabledCharacters: Set<String> = []

    private let maxConsecutiveFailures = 3

    // MARK: - Session Voice Anchor (음성 일관성)
    // [BUG FIX] seed 고정만으로는 다른 텍스트 → 다른 speaker zone 활성 → 다른 목소리 문제 해결 불가.
    // 해결: 캐릭터별 세션 첫 합성 출력을 "앵커"로 저장. 이후 호출은 앵커를 reference audio로
    //       synthesizeWithVoiceClone()에 넘겨 동일 목소리 경로를 유지.
    //
    // 정책:
    //   - voice clone 파일 모드(voiceCloneEnabled=true)가 켜지면 앵커 경로는 건너뜀.
    //   - 앵커 품질 게이트 실패 시 해당 호출만 base로 fallback (앵커 유지).
    //   - clearVoiceCache() 호출 시 앵커도 초기화.
    private var sessionVoiceAnchors: [String: [Float]] = [:]

    // MARK: - Voice Consistency Seed
    // [BUG FIX] 캐릭터 음성 일관성: 같은 캐릭터 문장마다 다른 목소리 문제
    // 원인: SamplingConfig에 seed 파라미터 없음, MLXRandom.gumbel()이 매 호출마다 다른 랜덤 시퀀스 생성
    // 해결: 합성 직전 MLXRandom.seed(캐릭터명 해시) 고정 → 동일 캐릭터 동일 음성 토큰 경로 보장
    private func characterSeed(for name: String) -> UInt64 {
        // 캐릭터명 UTF-8 해시 → 안정적이고 충돌 없는 UInt64
        var hash: UInt64 = 0xcbf29ce484222325  // FNV-1a offset basis
        for byte in name.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3  // FNV prime
        }
        // 0이면 fallback (MLXRandom.seed(0)이 no-op일 수 있음)
        return hash == 0 ? 0x1234567890ABCDEF : hash
    }

    /// 결과 품질 게이트: duration이 입력 대비 비정상이면 true
    /// - isVoiceClone: true면 prosody 확장 허용 (voice clone은 기본 합성보다 길게 생성되는 경향)
    private func isQualityGateFailed(text: String, samples: [Float], isVoiceClone: Bool = false) -> Bool {
        let duration = Double(samples.count) / 24000.0
        let expectedMin = Double(text.count) * 0.05   // 글자당 최소 50ms
        let maxMultiplier = isVoiceClone ? 1.5 : 0.8  // voice clone: 글자당 최대 1500ms (prosody 여유)
        let expectedMax = Double(text.count) * maxMultiplier
        // 너무 짧거나(기계음) 너무 길면(붕괴 징후) 실패
        return duration < expectedMin || duration > expectedMax || samples.count < 2400
    }

    private func recordCloneSuccess(characterName: String) {
        consecutiveFailures[characterName] = 0
    }

    private func recordCloneFailure(characterName: String, reason: TTSFallbackReason) {
        let count = (consecutiveFailures[characterName] ?? 0) + 1
        consecutiveFailures[characterName] = count
        AppLog.warning("[TTS Fallback] \(characterName): \(reason.rawValue) (연속 \(count)회)")
        if count >= maxConsecutiveFailures {
            sessionDisabledCharacters.insert(characterName)
            AppLog.warning("[TTS Fallback] \(characterName): 연속 \(maxConsecutiveFailures)회 실패 → 세션 동안 voice clone 비활성")
        }
    }

    nonisolated private init() {}

    // MARK: - Runtime Probe

    private struct ProbeRun: Codable {
        let timestamp: String
        let modelId: String
        let runtimeVoiceCloneEnabled: Bool
        let voiceCloneProbeIncluded: Bool
        let outputDirectory: String
        let results: [ProbeResult]
    }

    private struct ProbeResult: Codable {
        let characterName: String
        let mode: String
        let text: String
        let referenceLoaded: Bool
        let referenceDuration: Double?
        let referenceClippedDuration: Double?
        let synthSeconds: Double?
        let audioDuration: Double?
        let realTimeFactor: Double?
        let sampleCount: Int
        let wavPath: String?
        let error: String?
    }

    /// Development-only app-runtime probe. Trigger with MYTEAM_TTS_PROBE=1.
    /// Runs inside MyTeam.app, using the same bundle resources and Swift package runtime as release code.
    func runRuntimeProbe() async {
        probeLog("entered actor")
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let outDir = probeOutputDirectory().appendingPathComponent("run-\(timestamp)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        } catch {
            probeLog("❌ 출력 디렉토리 생성 실패: \(error)")
            return
        }

        probeLog("🚦 앱 런타임 TTS Probe 시작")
        probeLog("출력: \(outDir.path)")

        var results: [ProbeResult] = []
        let modelLoadStart = CFAbsoluteTimeGetCurrent()

        do {
            _ = try await loadModelIfNeeded()
            let modelLoadSeconds = CFAbsoluteTimeGetCurrent() - modelLoadStart
            probeLog(String(format: "모델 준비 완료: %.2fs", modelLoadSeconds))
        } catch {
            let result = ProbeResult(
                characterName: "_model",
                mode: "load",
                text: "",
                referenceLoaded: false,
                referenceDuration: nil,
                referenceClippedDuration: nil,
                synthSeconds: nil,
                audioDuration: nil,
                realTimeFactor: nil,
                sampleCount: 0,
                wavPath: nil,
                error: String(describing: error)
            )
            results.append(result)
            writeProbeRun(timestamp: timestamp, outDir: outDir, results: results)
            return
        }

        let characterNames = probeCharacterNames()
        let includeVoiceClone = probeShouldIncludeVoiceClone()

        for name in characterNames {
            let text = "\(name), 안녕하세요. 지금 목소리 확인 중이에요."
            results.append(await synthesizeProbeSample(
                characterName: name,
                mode: "base",
                text: text,
                outDir: outDir
            ))
            if includeVoiceClone {
                results.append(await synthesizeProbeSample(
                    characterName: name,
                    mode: "voiceClone",
                    text: text,
                    outDir: outDir
                ))
            }
        }

        writeProbeRun(timestamp: timestamp, outDir: outDir, results: results)
        probeLog("✅ 완료: \(outDir.path)")
    }

    private func synthesizeProbeSample(
        characterName: String,
        mode: String,
        text: String,
        outDir: URL
    ) async -> ProbeResult {
        do {
            let model = try await loadModelIfNeeded()
            let sampling = SamplingConfig(
                temperature: mode == "voiceClone" ? 0.35 : 0.45,
                topK: mode == "voiceClone" ? 25 : 30,
                maxTokens: 768
            )

            let reference: [Float]?
            let clippedReference: [Float]?
            if mode == "voiceClone" {
                reference = loadReferenceAudio(characterName: characterName)
                clippedReference = reference.map { clippedReferenceAudio($0) }
            } else {
                reference = nil
                clippedReference = nil
            }

            let start = CFAbsoluteTimeGetCurrent()
            let samples: [Float]
            if mode == "voiceClone", let clippedReference {
                samples = model.synthesizeWithVoiceClone(
                    text: text,
                    referenceAudio: clippedReference,
                    referenceSampleRate: 24000,
                    language: "korean",
                    sampling: sampling
                )
            } else {
                samples = model.synthesize(
                    text: text,
                    language: "korean",
                    sampling: sampling
                )
            }
            let synthSeconds = CFAbsoluteTimeGetCurrent() - start
            let audioDuration = Double(samples.count) / 24000.0
            let refDuration = reference.map { Double($0.count) / 24000.0 }
            let clippedRefDuration = clippedReference.map { Double($0.count) / 24000.0 }
            let rtf = synthSeconds / max(audioDuration, 0.001)

            let fileName = "\(mode)_\(characterName)_\(Int(synthSeconds * 1000))ms.wav"
            let wavURL = outDir.appendingPathComponent(fileName)
            try writeWAV(samples: samples, sampleRate: 24000, to: wavURL)

            probeLog(String(format: "%@/%@ synth=%.2fs audio=%.2fs rtf=%.2f samples=%d",
                            characterName, mode, synthSeconds, audioDuration, rtf, samples.count))

            return ProbeResult(
                characterName: characterName,
                mode: mode,
                text: text,
                referenceLoaded: reference != nil,
                referenceDuration: refDuration,
                referenceClippedDuration: clippedRefDuration,
                synthSeconds: synthSeconds,
                audioDuration: audioDuration,
                realTimeFactor: rtf,
                sampleCount: samples.count,
                wavPath: wavURL.path,
                error: nil
            )
        } catch {
            probeLog("❌ \(characterName)/\(mode): \(error)")
            return ProbeResult(
                characterName: characterName,
                mode: mode,
                text: text,
                referenceLoaded: false,
                referenceDuration: nil,
                referenceClippedDuration: nil,
                synthSeconds: nil,
                audioDuration: nil,
                realTimeFactor: nil,
                sampleCount: 0,
                wavPath: nil,
                error: String(describing: error)
            )
        }
    }

    private func writeProbeRun(timestamp: String, outDir: URL, results: [ProbeResult]) {
        let run = ProbeRun(
            timestamp: timestamp,
            modelId: ModelCatalog.resolvedTTSModelId(),
            runtimeVoiceCloneEnabled: Self.isRuntimeVoiceCloneEnabled,
            voiceCloneProbeIncluded: probeShouldIncludeVoiceClone(),
            outputDirectory: outDir.path,
            results: results
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(run)
            try data.write(to: outDir.appendingPathComponent("results.json"))
        } catch {
            probeLog("❌ results.json 저장 실패: \(error)")
        }
    }

    private func probeLog(_ message: String) {
        AppLog.info("[TTSProbe] \(message)")
        fflush(stdout)
    }

    private func probeOutputDirectory() -> URL {
        AppPaths.ttsBenchDirectory
    }

    private func probeCharacterNames() -> [String] {
        if let raw = ProcessInfo.processInfo.environment["MYTEAM_TTS_PROBE_CHARACTERS"] {
            let names = raw
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !names.isEmpty {
                return names
            }
        }

        return [
            "루나", "레오", "모코", "핀", "치코", "렉스",
            "케이", "래키", "폴라", "몽몽", "올리버"
        ]
    }

    private func probeShouldIncludeVoiceClone() -> Bool {
        ProcessInfo.processInfo.environment["MYTEAM_TTS_PROBE_INCLUDE_VOICE_CLONE"] == "1"
    }

    private func writeWAV(samples: [Float], sampleRate: Int, to url: URL) throws {
        var data = Data()
        let channels = 1
        let bitsPerSample = 16
        let bytesPerSample = bitsPerSample / 8
        let byteRate = sampleRate * channels * bytesPerSample
        let blockAlign = channels * bytesPerSample
        let dataSize = samples.count * bytesPerSample
        let chunkSize = 36 + dataSize

        func appendString(_ value: String) {
            data.append(contentsOf: value.utf8)
        }

        func appendUInt16(_ value: UInt16) {
            var little = value.littleEndian
            data.append(Data(bytes: &little, count: MemoryLayout<UInt16>.size))
        }

        func appendUInt32(_ value: UInt32) {
            var little = value.littleEndian
            data.append(Data(bytes: &little, count: MemoryLayout<UInt32>.size))
        }

        appendString("RIFF")
        appendUInt32(UInt32(chunkSize))
        appendString("WAVE")
        appendString("fmt ")
        appendUInt32(16)
        appendUInt16(1)
        appendUInt16(UInt16(channels))
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(byteRate))
        appendUInt16(UInt16(blockAlign))
        appendUInt16(UInt16(bitsPerSample))
        appendString("data")
        appendUInt32(UInt32(dataSize))

        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let intSample = Int16(clamped * Float(Int16.max))
            appendUInt16(UInt16(bitPattern: intSample))
        }

        try data.write(to: url)
    }

    // MARK: - Public Interface (MLXInferenceService 호환)

    nonisolated func generateTTSStream(text: String, characterName: String) -> AsyncStream<Data> {
        AsyncStream(Data.self, bufferingPolicy: .unbounded) { continuation in
            Task { @Qwen3TTSActor in
                defer { continuation.finish() }
                do {
                    try await self.runPipeline(text: text, characterName: characterName,
                                              continuation: continuation)
                } catch is CancellationError {
                    AppLog.info("[Qwen3TTSService] 🛑 취소됨 (\(characterName))")
                } catch {
                    AppLog.info("[Qwen3TTSService] ❌ 오류: \(error)")
                }
            }
        }
    }

    func cancelCurrentInference() {
        speechTask?.cancel()
        speechTask = nil
        AppLog.info("[Qwen3TTSService] 🛑 추론 취소 (Barge-in)")
    }

    /// 세션 음성 앵커 전체 초기화 — 다음 발화부터 다시 base synthesis로 앵커 재설정
    func clearSessionAnchors() {
        sessionVoiceAnchors.removeAll()
        AppLog.info("[Qwen3TTSService] 🔄 세션 앵커 초기화 완료")
    }

    /// 특정 캐릭터 앵커만 초기화 (해당 캐릭터 목소리 리셋)
    func clearSessionAnchor(for characterName: String) {
        sessionVoiceAnchors.removeValue(forKey: characterName)
        AppLog.info("[Qwen3TTSService] 🔄 \(characterName) 세션 앵커 초기화")
    }

    // MARK: - Pipeline

    private func runPipeline(
        text: String,
        characterName: String,
        continuation: AsyncStream<Data>.Continuation
    ) async throws {
        // 이전 추론 즉시 취소
        speechTask?.cancel()

        let task = Task { @Qwen3TTSActor in
            guard !Task.isCancelled else { return }
            try await self.performInference(text: text, characterName: characterName,
                                           continuation: continuation)
        }
        speechTask = task
        try await task.value
    }

    private func performInference(
        text: String,
        characterName: String,
        continuation: AsyncStream<Data>.Continuation
    ) async throws {
        // 1. 모델 lazy 초기화 (첫 발화 시 1회 다운로드)
        let model = try await loadModelIfNeeded()
        if Task.isCancelled { return }

        // 2. Voice clone 가용 여부 판단
        //    - 글로벌 토글 OFF → base
        //    - 세션 내 연속 실패로 비활성 → base
        //    - 레퍼런스 못 찾으면 → base
        let voiceCloneEnabled = Self.isRuntimeVoiceCloneEnabled
            && !sessionDisabledCharacters.contains(characterName)

        let refAudio: [Float]?
        if voiceCloneEnabled {
            if let loaded = loadReferenceAudio(characterName: characterName).map({ clippedReferenceAudio($0) }) {
                refAudio = loaded
            } else {
                recordCloneFailure(characterName: characterName, reason: .referenceNotFound)
                refAudio = nil
            }
        } else {
            refAudio = nil
        }

        // 3. TTS 추론
        // seed 고정: 동일 텍스트 재현성 보장 (다른 텍스트 간 일관성은 세션 앵커로 해결)
        MLXRandom.seed(characterSeed(for: characterName))

        let samplingConfig = SamplingConfig(
            temperature: refAudio == nil ? 0.45 : 0.35,
            topK: refAudio == nil ? 30 : 25,
            maxTokens: 768
        )

        AppLog.info("[Qwen3TTSService] 🎙️ \(characterName): \"\(text.prefix(30))...\"")
        let startTime = CFAbsoluteTimeGetCurrent()

        var samples: [Float]
        var usedFileClone = false

        // 3-a. 파일 기반 voice clone (voiceCloneEnabled=true일 때)
        if let refAudio {
            AppLog.info("[Qwen3TTSService] 🎧 \(characterName) 레퍼런스 기반 합성")
            samples = model.synthesizeWithVoiceClone(
                text: text,
                referenceAudio: refAudio,
                referenceSampleRate: 24000,
                language: "korean",
                sampling: samplingConfig
            )
            usedFileClone = true

        // 3-b. 세션 앵커 기반 합성 (음성 일관성 — 두 번째 발화부터)
        } else if let anchor = sessionVoiceAnchors[characterName] {
            AppLog.info("[Qwen3TTSService] 🔗 \(characterName) 세션 앵커 기반 합성 (voice consistency)")
            // paddedClippedReferenceAudio: 짧은 앵커를 루프 패딩해 3초 이상 확보
            // (1~2초 짧은 앵커는 voice clone이 75 token safety limit에 걸려 6초짜리 반복 오디오 생성 버그 수정)
            let anchorRef = paddedClippedReferenceAudio(anchor)
            let anchorSamples = model.synthesizeWithVoiceClone(
                text: text,
                referenceAudio: anchorRef,
                referenceSampleRate: 24000,
                language: "korean",
                sampling: SamplingConfig(temperature: 0.30, topK: 20, maxTokens: 768)
            )
            // 앵커 품질 게이트: voice clone prosody 확장 허용 (isVoiceClone=true → expectedMax 1.5s/글자)
            if isQualityGateFailed(text: text, samples: anchorSamples, isVoiceClone: true) {
                AppLog.warning("[Qwen3TTSService] ⚠️ \(characterName) 앵커 품질 미달 → base fallback (앵커 유지)")
                samples = model.synthesize(text: text, language: "korean",
                                           sampling: SamplingConfig(temperature: 0.45, topK: 30, maxTokens: 768))
            } else {
                samples = anchorSamples
            }

        // 3-c. 첫 합성 — base synthesis + 결과를 앵커로 저장
        } else {
            AppLog.info("[Qwen3TTSService] 🎤 \(characterName) 첫 합성 (base) → 세션 앵커 저장 예정")
            samples = model.synthesize(
                text: text,
                language: "korean",
                sampling: samplingConfig
            )
            // 품질이 충분하면 세션 앵커로 저장 (이후 발화는 이 목소리로 고정)
            if !isQualityGateFailed(text: text, samples: samples) && samples.count >= 2400 {
                sessionVoiceAnchors[characterName] = samples
                let anchorDur = String(format: "%.1f", Double(samples.count) / 24000.0)
                AppLog.info("[Qwen3TTSService] 🎯 \(characterName) 세션 앵커 저장 완료 (~\(anchorDur)s)")
            }
        }

        // 4. 파일 voice clone Quality gate — 실패 시 base 재합성 + 실패 카운트
        if usedFileClone && isQualityGateFailed(text: text, samples: samples) {
            recordCloneFailure(characterName: characterName, reason: .qualityGateFailed)
            AppLog.info("[Qwen3TTSService] ⚠️ \(characterName) voice clone 품질 미달 → base 재합성")
            samples = model.synthesize(
                text: text,
                language: "korean",
                sampling: SamplingConfig(temperature: 0.45, topK: 30, maxTokens: 768)
            )
        } else if usedFileClone {
            recordCloneSuccess(characterName: characterName)
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let duration = Double(samples.count) / 24000.0
        AppLog.info(String(format: "[Qwen3TTSService] ✅ %@ %.2fs 오디오 생성 완료 (%.2fs, RTF %.2f)",
                     characterName, duration, elapsed, elapsed / max(duration, 0.001)))

        if Task.isCancelled { return }

        // 4. Float32 PCM을 4096샘플 청크로 스트리밍 (AudioPlaybackService 호환)
        let chunkSize = 4096
        var offset = 0
        while offset < samples.count {
            if Task.isCancelled { break }
            let end = min(offset + chunkSize, samples.count)
            let chunk = Array(samples[offset..<end])
            let data = chunk.withUnsafeBytes { Data($0) }
            continuation.yield(data)
            offset = end
        }
    }

    private func clippedReferenceAudio(_ samples: [Float]) -> [Float] {
        let maxSamples = 24000 * 7
        guard samples.count > maxSamples else { return samples }
        return Array(samples.prefix(maxSamples))
    }

    /// 세션 앵커 전용 레퍼런스 오디오 준비.
    /// 최소 3초 보장: 짧은 앵커는 루프 패딩으로 채워 voice clone 과잉 생성 방지.
    /// (앵커 < 2s → voice clone이 75 token safety limit에 걸려 6초짜리 반복 오디오 생성하는 버그 수정)
    private func paddedClippedReferenceAudio(_ samples: [Float]) -> [Float] {
        let minSamples = 24000 * 3   // 3초 최소
        let maxSamples = 24000 * 7   // 7초 최대 (기존 cap)
        if samples.count >= maxSamples { return Array(samples.prefix(maxSamples)) }
        if samples.count >= minSamples { return samples }
        // 루프 패딩
        var padded = [Float]()
        padded.reserveCapacity(minSamples)
        while padded.count < minSamples { padded.append(contentsOf: samples) }
        return Array(padded.prefix(maxSamples))
    }

    nonisolated static var isRuntimeVoiceCloneEnabled: Bool {
        UserDefaults.standard.object(forKey: voiceCloneDefaultsKey) as? Bool ?? false
    }

    // MARK: - Model Loader

    private func loadModelIfNeeded() async throws -> Qwen3TTSModel {
        if let model = ttsModel { return model }
        guard !isLoading else {
            // 다른 태스크가 로딩 중이면 짧게 대기 후 재시도
            try await Task.sleep(nanoseconds: 500_000_000)
            return try await loadModelIfNeeded()
        }
        isLoading = true
        defer { isLoading = false }

        let modelId = ModelCatalog.resolvedTTSModelId()
        try validateModelCacheExists(modelId: modelId)

        runtimeLog("[Qwen3TTSService] 📥 Qwen3-TTS 1.7B 모델 로딩 시작...")
        let model = try await Qwen3TTSModel.fromPretrained(
            modelId: modelId
        ) { progress, status in
            self.runtimeLog(String(format: "[Qwen3TTSService] 로딩 [%d%%] %@",
                                   Int(progress * 100), status))
        }
        ttsModel = model
        runtimeLog("[Qwen3TTSService] ✅ 모델 로딩 완료")
        return model
    }

    private func runtimeLog(_ message: String) {
        AppLog.info(message, .tts)
    }

    private func validateModelCacheExists(modelId: String) throws {
        let modelWeights = qwenCachePath(for: modelId).appendingPathComponent("model.safetensors")
        let tokenizerWeights = qwenCachePath(for: "Qwen/Qwen3-TTS-Tokenizer-12Hz").appendingPathComponent("model.safetensors")
        let missing = [modelWeights, tokenizerWeights].filter { !FileManager.default.fileExists(atPath: $0.path) }
        guard missing.isEmpty else {
            throw NSError(
                domain: "MyTeam.TTS",
                code: 1001,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Qwen3 모델 캐시가 앱 컨테이너에 없습니다. 출시 경로에서는 자동 다운로드를 막고 ODR/명시 다운로드/TTS 보류 중 하나를 결정해야 합니다. missing=\(missing.map(\.lastPathComponent).joined(separator: ","))"
                ]
            )
        }
    }

    private func qwenCachePath(for modelId: String) -> URL {
        modelId.split(separator: "/").reduce(
            AppPaths.qwenSpeechCacheDirectory.appendingPathComponent("models", isDirectory: true)
        ) { partial, component in
            partial.appendingPathComponent(String(component), isDirectory: true)
        }
    }

    // MARK: - Reference Audio Loader

    /// 캐릭터별 레퍼런스 오디오 로드 (캐시)
    /// Resources/ReferenceAudio/{name}_reference.mp3 → Float32 24kHz
    /// macOS HFS+/APFS가 한글 파일명을 NFD로 저장하므로 Bundle API 검색이 실패할 수 있음.
    /// 여러 방법 시도 후 resourcePath 직접 접근으로 폴백.
    private func loadReferenceAudio(characterName: String) -> [Float]? {
        if let cached = voiceCache[characterName] { return cached }

        let fileName = "\(characterName)_reference"

        func findURL() -> URL? {
            // 1. Bundle API — subdirectory 지정 (NFC)
            if let u = Bundle.main.url(forResource: fileName, withExtension: "mp3", subdirectory: "ReferenceAudio") { return u }
            if let u = Bundle.main.url(forResource: fileName, withExtension: "wav", subdirectory: "ReferenceAudio") { return u }
            // 2. Bundle API — subdirectory 없이 (flat)
            if let u = Bundle.main.url(forResource: fileName, withExtension: "mp3") { return u }
            if let u = Bundle.main.url(forResource: fileName, withExtension: "wav") { return u }
            // 3. NFD 정규화 시도
            let nfdName = (fileName as NSString).decomposedStringWithCanonicalMapping
            if let u = Bundle.main.url(forResource: nfdName, withExtension: "mp3", subdirectory: "ReferenceAudio") { return u }
            if let u = Bundle.main.url(forResource: nfdName, withExtension: "mp3") { return u }
            // 4. resourcePath 직접 접근 (한글 NFD 파일명 폴백)
            guard let rp = Bundle.main.resourcePath else { return nil }
            let candidates = [
                "\(rp)/ReferenceAudio/\(fileName).mp3",
                "\(rp)/ReferenceAudio/\(fileName).wav",
                "\(rp)/\(fileName).mp3",
                "\(rp)/\(fileName).wav",
                "\(rp)/ReferenceAudio/\(nfdName).mp3",
                "\(rp)/\(nfdName).mp3",
            ]
            return candidates.compactMap { FileManager.default.fileExists(atPath: $0) ? URL(fileURLWithPath: $0) : nil }.first
        }

        guard let url = findURL() else {
            AppLog.info("[Qwen3TTSService] ⚠️ \(characterName) 레퍼런스 오디오 파일을 찾을 수 없음 — 기본 목소리 사용")
            if let rp = Bundle.main.resourcePath {
                let refDir = "\(rp)/ReferenceAudio"
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: refDir) {
                    AppLog.info("[Qwen3TTSService]   ReferenceAudio 폴더 내용: \(contents.prefix(5))")
                } else {
                    AppLog.info("[Qwen3TTSService]   ReferenceAudio 폴더 자체가 번들에 없음!")
                }
            }
            return nil
        }

        do {
            let samples = try loadAudioFile(url: url, targetSampleRate: 24000)
            voiceCache[characterName] = samples
            let durationSec = Double(samples.count) / 24000.0
            AppLog.info(String(format: "[Qwen3TTSService] 🎵 %@ 레퍼런스 로드: %d samples (%.2fs) from %@",
                         characterName, samples.count, durationSec, url.lastPathComponent))
            return samples
        } catch {
            AppLog.info("[Qwen3TTSService] ⚠️ 레퍼런스 오디오 로드 실패: \(error)")
            return nil
        }
    }

    /// AVFoundation으로 오디오 파일을 Float32 PCM으로 디코딩
    private func loadAudioFile(url: URL, targetSampleRate: Double) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let srcFormat = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)

        // 원본 형식으로 읽기
        let srcBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: frameCount)!
        try file.read(into: srcBuffer)

        // 타겟 형식 (24kHz mono Float32)
        let dstFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        )!

        // 리샘플링
        guard let converter = AVAudioConverter(from: srcFormat, to: dstFormat) else {
            throw NSError(domain: "Qwen3TTS", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "AVAudioConverter 생성 실패"])
        }

        let ratio = targetSampleRate / srcFormat.sampleRate
        let dstFrameCount = AVAudioFrameCount(Double(frameCount) * ratio)
        let dstBuffer = AVAudioPCMBuffer(pcmFormat: dstFormat, frameCapacity: dstFrameCount)!

        try converter.convert(to: dstBuffer, from: srcBuffer)

        guard let channelData = dstBuffer.floatChannelData else { return [] }
        let count = Int(dstBuffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData[0], count: count))
    }
}
