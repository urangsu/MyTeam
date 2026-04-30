import Foundation
import AVFoundation
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

    private var ttsModel: Qwen3TTSModel?
    private var isLoading = false

    // 캐릭터별 레퍼런스 오디오 캐시 (24kHz Float32)
    private var voiceCache: [String: [Float]] = [:]

    // 즉시 취소용 현재 태스크
    private var speechTask: Task<Void, Error>?

    nonisolated private init() {}

    // MARK: - Runtime Probe

    private struct ProbeRun: Codable {
        let timestamp: String
        let modelId: String
        let outputDirectory: String
        let results: [ProbeResult]
    }

    private struct ProbeResult: Codable {
        let characterName: String
        let mode: String
        let text: String
        let referenceLoaded: Bool
        let referenceDuration: Double?
        let synthSeconds: Double?
        let audioDuration: Double?
        let sampleCount: Int
        let wavPath: String?
        let error: String?
    }

    /// Development-only app-runtime probe. Trigger with MYTEAM_TTS_PROBE=1.
    /// Runs inside MyTeam.app, using the same bundle resources and Swift package runtime as release code.
    func runRuntimeProbe() async {
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let outDir = probeOutputDirectory().appendingPathComponent("run-\(timestamp)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        } catch {
            print("[TTSProbe] ❌ 출력 디렉토리 생성 실패: \(error)")
            return
        }

        print("[TTSProbe] 🚦 앱 런타임 TTS Probe 시작")
        print("[TTSProbe] 출력: \(outDir.path)")

        var results: [ProbeResult] = []
        let modelLoadStart = CFAbsoluteTimeGetCurrent()

        do {
            _ = try await loadModelIfNeeded()
            let modelLoadSeconds = CFAbsoluteTimeGetCurrent() - modelLoadStart
            print(String(format: "[TTSProbe] 모델 준비 완료: %.2fs", modelLoadSeconds))
        } catch {
            let result = ProbeResult(
                characterName: "_model",
                mode: "load",
                text: "",
                referenceLoaded: false,
                referenceDuration: nil,
                synthSeconds: nil,
                audioDuration: nil,
                sampleCount: 0,
                wavPath: nil,
                error: String(describing: error)
            )
            results.append(result)
            writeProbeRun(timestamp: timestamp, outDir: outDir, results: results)
            return
        }

        let baseText = "수석님, 지금 앱 안에서 음성 테스트 중이에요."
        results.append(await synthesizeProbeSample(
            characterName: "기본",
            mode: "base",
            text: baseText,
            outDir: outDir
        ))

        let characterNames = probeCharacterNames()

        for name in characterNames {
            let text = "\(name), 안녕하세요. 지금 목소리 확인 중이에요."
            results.append(await synthesizeProbeSample(
                characterName: name,
                mode: "voiceClone",
                text: text,
                outDir: outDir
            ))
        }

        writeProbeRun(timestamp: timestamp, outDir: outDir, results: results)
        print("[TTSProbe] ✅ 완료: \(outDir.path)")
    }

    private func synthesizeProbeSample(
        characterName: String,
        mode: String,
        text: String,
        outDir: URL
    ) async -> ProbeResult {
        do {
            let model = try await loadModelIfNeeded()
            let sampling = SamplingConfig(temperature: 0.9, topK: 50, maxTokens: 4096)

            let reference: [Float]?
            if mode == "voiceClone" {
                reference = loadReferenceAudio(characterName: characterName)
            } else {
                reference = nil
            }

            let start = CFAbsoluteTimeGetCurrent()
            let samples: [Float]
            if mode == "voiceClone", let reference {
                samples = model.synthesizeWithVoiceClone(
                    text: text,
                    referenceAudio: reference,
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

            let fileName = "\(mode)_\(characterName)_\(Int(synthSeconds * 1000))ms.wav"
            let wavURL = outDir.appendingPathComponent(fileName)
            try writeWAV(samples: samples, sampleRate: 24000, to: wavURL)

            print(String(format: "[TTSProbe] %@/%@ synth=%.2fs audio=%.2fs samples=%d",
                         characterName, mode, synthSeconds, audioDuration, samples.count))

            return ProbeResult(
                characterName: characterName,
                mode: mode,
                text: text,
                referenceLoaded: reference != nil,
                referenceDuration: refDuration,
                synthSeconds: synthSeconds,
                audioDuration: audioDuration,
                sampleCount: samples.count,
                wavPath: wavURL.path,
                error: nil
            )
        } catch {
            print("[TTSProbe] ❌ \(characterName)/\(mode): \(error)")
            return ProbeResult(
                characterName: characterName,
                mode: mode,
                text: text,
                referenceLoaded: false,
                referenceDuration: nil,
                synthSeconds: nil,
                audioDuration: nil,
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
            outputDirectory: outDir.path,
            results: results
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(run)
            try data.write(to: outDir.appendingPathComponent("results.json"))
        } catch {
            print("[TTSProbe] ❌ results.json 저장 실패: \(error)")
        }
    }

    private func probeOutputDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("MyTeam/TTSBench", isDirectory: true)
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
                    print("[Qwen3TTSService] 🛑 취소됨 (\(characterName))")
                } catch {
                    print("[Qwen3TTSService] ❌ 오류: \(error)")
                }
            }
        }
    }

    func cancelCurrentInference() {
        speechTask?.cancel()
        speechTask = nil
        print("[Qwen3TTSService] 🛑 추론 취소 (Barge-in)")
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

        // 2. 캐릭터별 레퍼런스 고정. 레퍼런스가 없을 때만 기본 합성으로 fallback.
        let refAudio = loadReferenceAudio(characterName: characterName)

        // 3. TTS 추론
        // 낮은 temperature로 같은 캐릭터가 매번 다른 목소리처럼 흔들리는 현상 완화.
        let samplingConfig = SamplingConfig(temperature: refAudio == nil ? 0.55 : 0.35, topK: refAudio == nil ? 40 : 25, maxTokens: 4096)

        print("[Qwen3TTSService] 🎙️ \(characterName): \"\(text.prefix(30))...\"")
        let startTime = CFAbsoluteTimeGetCurrent()

        let samples: [Float]
        if let refAudio {
            print("[Qwen3TTSService] 🎧 \(characterName) 레퍼런스 기반 합성")
            samples = model.synthesizeWithVoiceClone(
                text: text,
                referenceAudio: refAudio,
                referenceSampleRate: 24000,
                language: "korean",
                sampling: samplingConfig
            )
        } else {
            print("[Qwen3TTSService] ⚠️ \(characterName) 레퍼런스 없음 — 기본 음성 fallback")
            samples = model.synthesize(
                text: text,
                language: "korean",
                sampling: samplingConfig
            )
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let duration = Double(samples.count) / 24000.0
        print(String(format: "[Qwen3TTSService] ✅ %@ %.2fs 오디오 생성 완료 (%.2fs, RTF %.2f)",
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

        print("[Qwen3TTSService] 📥 Qwen3-TTS 1.7B 모델 로딩 시작...")
        let model = try await Qwen3TTSModel.fromPretrained(
            modelId: ModelCatalog.resolvedTTSModelId()
        ) { progress, status in
            print(String(format: "[Qwen3TTSService] 로딩 [%d%%] %@",
                         Int(progress * 100), status))
        }
        ttsModel = model
        print("[Qwen3TTSService] ✅ 모델 로딩 완료")
        return model
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
            print("[Qwen3TTSService] ⚠️ \(characterName) 레퍼런스 오디오 파일을 찾을 수 없음 — 기본 목소리 사용")
            if let rp = Bundle.main.resourcePath {
                let refDir = "\(rp)/ReferenceAudio"
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: refDir) {
                    print("[Qwen3TTSService]   ReferenceAudio 폴더 내용: \(contents.prefix(5))")
                } else {
                    print("[Qwen3TTSService]   ReferenceAudio 폴더 자체가 번들에 없음!")
                }
            }
            return nil
        }

        do {
            let samples = try loadAudioFile(url: url, targetSampleRate: 24000)
            voiceCache[characterName] = samples
            let durationSec = Double(samples.count) / 24000.0
            print(String(format: "[Qwen3TTSService] 🎵 %@ 레퍼런스 로드: %d samples (%.2fs) from %@",
                         characterName, samples.count, durationSec, url.lastPathComponent))
            return samples
        } catch {
            print("[Qwen3TTSService] ⚠️ 레퍼런스 오디오 로드 실패: \(error)")
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

        var error: NSError?
        var inputConsumed = false
        converter.convert(to: dstBuffer, error: &error) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            outStatus.pointee = .haveData
            inputConsumed = true
            return srcBuffer
        }
        if let e = error { throw e }

        guard let channelData = dstBuffer.floatChannelData else { return [] }
        let count = Int(dstBuffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData[0], count: count))
    }
}
