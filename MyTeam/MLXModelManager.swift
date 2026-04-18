import Foundation
import MLX
@preconcurrency import AVFoundation

// MARK: - Error Types
enum MLXModelError: Error, LocalizedError {
    case weightsNotFound(String)
    case embeddingNotFound(String)
    case wavFileNotFound(String)
    case audioDecodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .weightsNotFound(let f):    return "[MLXModelManager] ❌ 가중치 없음: \(f)"
        case .embeddingNotFound(let f):  return "[MLXModelManager] ❌ 임베딩 없음: \(f)"
        case .wavFileNotFound(let name): return "[MLXModelManager] ❌ \(name)_reference.wav 없음 — MP3 사용 불가"
        case .audioDecodingFailed(let n): return "[MLXModelManager] ❌ WAV 디코딩 실패: \(n)"
        }
    }
}

// MARK: - URL Bundle for NPY embeddings
struct T3EmbeddingURLs {
    let textEmb: URL
    let speechEmb: URL
    let textPosEmb: URL
    let speechPosEmb: URL
    let spkrEncWeight: URL
    let spkrEncBias: URL
}

// MARK: - MLXModelManager
actor MLXModelManager {
    static let shared = MLXModelManager()

    private var ttsModel: T3MLXModel?
    // Zero-Shot: 캐릭터명 → WAV 텐서 (무손실 전용)
    private var referenceAudioTensors: [String: MLXArray] = [:]
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private var lruEvictionTask: Task<Void, Never>?
    private let lruTimeoutSeconds: UInt64 = 1800 // 30분

    private init() {
        Task { await setupMemoryPressureMonitor() }
    }

    // MARK: - Zero-Shot Reference Audio (투트랙: WAV 우선 → MP3 폴백)
    /// 1순위: {name}_reference.wav (24kHz 16-bit Mono PCM, 무손실)
    /// 2순위: {name}_reference.mp3 (테스트용 폴백, 경고 로그 출력)
    /// 3순위: nil 반환
    func loadReferenceAudioIfNeeded(characterName: String) async -> MLXArray? {
        if let cached = referenceAudioTensors[characterName] { return cached }

        let resName = "\(characterName)_reference"

        // 레퍼런스 오디오 탐색 (4단계 폴백)
        // 1) ReferenceAudio 서브디렉토리 WAV  (folder reference — 디렉토리 구조 보존)
        // 2) 번들 루트 WAV                   (group — 평탄화)
        // 3) ReferenceAudio 서브디렉토리 MP3
        // 4) 번들 루트 MP3
        let url: URL
        if let u = Bundle.main.url(forResource: resName, withExtension: "wav",
                                   subdirectory: "ReferenceAudio") {
            url = u
        } else if let u = Bundle.main.url(forResource: resName, withExtension: "wav") {
            url = u
        } else if let u = Bundle.main.url(forResource: resName, withExtension: "mp3",
                                          subdirectory: "ReferenceAudio") {
            print("[MLXModelManager] ⚠️ WAV 에셋 누락. MP3 Fallback (\(characterName))")
            url = u
        } else if let u = Bundle.main.url(forResource: resName, withExtension: "mp3") {
            print("[MLXModelManager] ⚠️ WAV 에셋 누락. MP3 Fallback (\(characterName))")
            url = u
        } else {
            print("[MLXModelManager] ❌ \(characterName) 레퍼런스 에셋 없음 (WAV/MP3 모두 미존재)")
            return nil
        }

        guard let floats = decodeAudioToFloat32(url: url, targetSampleRate: 24000) else {
            print("[MLXModelManager] ❌ \(characterName) 오디오 디코딩 실패: \(url.lastPathComponent)")
            return nil
        }

        let tensor = MLXArray(floats)
        referenceAudioTensors[characterName] = tensor
        let durationSec = String(format: "%.2f", Double(floats.count) / 24000.0)
        print("[MLXModelManager] ✅ \(characterName) 레퍼런스 텐서 상주 완료 — \(floats.count) samples (\(durationSec)s @ 24kHz) [\(url.pathExtension.uppercased())]")
        return tensor
    }

    // MARK: - T3 FP16 Zero-Copy Load (파일 복사 금지, Memory Mapping 강제)
    /// 가중치를 Bundle URL에서 직접 Memory Mapping으로 통합 메모리에 적재
    /// copyWeightsToContainerIfNeeded() 호출 없음 — App Hang 원천 차단
    func loadModelIfNeeded() async throws -> T3MLXModel {
        resetLRUTimer()
        if let m = ttsModel { return m }

        let weightsURL = try resolveWeightsURL()
        let embURLs = try resolveEmbeddingURLs()

        print("[MLXModelManager] 🔥 T3 FP16 Zero-Copy Memory Mapping 적재 시작...")
        // T3MLXModel은 격리 — MLXModelManager 액터에서 직접 호출 불가
        // Swift 6 Task 반환 문법을 사용하여 액터 경계를 명시적으로 hop
        let model = try await Task.detached(priority: .high) {
            try T3MLXModel(weightsURL: weightsURL, embeddingURLs: embURLs)
        }.value
        ttsModel = model
        print("[MLXModelManager] 🚀 T3 FP16 Warm-Standby 완료")
        return model
    }

    // MARK: - URL 해결 (Bundle 우선, Dev 폴백)
    private func resolveWeightsURL() throws -> URL {
        let fileName = "t3_mlx_weights_fp16"
        let ext = "safetensors"

        // 1순위: Bundle 서브디렉토리 탐색
        if let url = Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "onnx_models") {
            print("[MLXModelManager] ✅ 번들에서 safetensors 가중치 발견!")
            return url
        }
        // 2순위: Bundle 루트 탐색
        if let url = Bundle.main.url(forResource: fileName, withExtension: ext) {
            print("[MLXModelManager] ✅ 번들 루트에서 safetensors 가중치 발견!")
            return url
        }
        // 3순위: 개발 절대 경로 강제 돌파
        let devPath = "/Users/su/Desktop/MyTeam/MyTeam/Resources/onnx_models/\(fileName).\(ext)"
        if FileManager.default.fileExists(atPath: devPath) {
            print("[MLXModelManager] ⚠️ 번들 누락! 개발자 절대 경로로 강제 로드!")
            return URL(fileURLWithPath: devPath)
        }
        // 4순위: TTS맨 레거시 경로
        let legacyPath = "/Users/su/Desktop/TTS맨/chatterbox/onnx_models/\(fileName).\(ext)"
        if FileManager.default.fileExists(atPath: legacyPath) {
            print("[MLXModelManager] ⚠️ TTS맨 레거시 경로에서 safetensors 발견!")
            return URL(fileURLWithPath: legacyPath)
        }

        throw MLXModelError.weightsNotFound("\(fileName).\(ext)")
    }

    private func resolveEmbeddingURLs() throws -> T3EmbeddingURLs {
        let devBase = URL(fileURLWithPath: "/Users/su/Desktop/TTS맨/chatterbox/onnx_models")

        func resolve(_ name: String) throws -> URL {
            if let u = Bundle.main.url(forResource: name, withExtension: "npy", subdirectory: "onnx_models") { return u }
            let u = devBase.appendingPathComponent("\(name).npy")
            guard FileManager.default.fileExists(atPath: u.path) else {
                throw MLXModelError.embeddingNotFound("\(name).npy")
            }
            return u
        }

        return T3EmbeddingURLs(
            textEmb:       try resolve("text_emb"),
            speechEmb:     try resolve("speech_emb"),
            textPosEmb:    try resolve("text_pos_emb"),
            speechPosEmb:  try resolve("speech_pos_emb"),
            spkrEncWeight: try resolve("spkr_enc_weight"),
            spkrEncBias:   try resolve("spkr_enc_bias")
        )
    }

    // MARK: - Audio → 24kHz mono Float32 (WAV/MP3 공용, AVAudioFile 자동 처리)
    private func decodeAudioToFloat32(url: URL, targetSampleRate: Double) -> [Float32]? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        )!
        let srcFormat = file.processingFormat

        // 포맷이 이미 일치하면 직접 반환
        if srcFormat.sampleRate == targetSampleRate && srcFormat.channelCount == 1,
           srcFormat.commonFormat == .pcmFormatFloat32 {
            guard let buf = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: AVAudioFrameCount(file.length)),
                  (try? file.read(into: buf)) != nil,
                  let ptr = buf.floatChannelData?[0] else { return nil }
            return Array(UnsafeBufferPointer(start: ptr, count: Int(buf.frameLength)))
        }

        // 리샘플 + 채널 변환
        let ratio = targetSampleRate / srcFormat.sampleRate
        let outFrames = AVAudioFrameCount(Double(file.length) * ratio + 1)

        guard let srcBuf = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: srcBuf)) != nil,
              let outBuf = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outFrames),
              let conv = AVAudioConverter(from: srcFormat, to: targetFormat) else { return nil }

        class ConvState: @unchecked Sendable { var consumed = false }
        let state = ConvState()
        conv.convert(to: outBuf, error: nil) { _, status in
            if !state.consumed { state.consumed = true; status.pointee = .haveData; return srcBuf }
            status.pointee = .endOfStream; return nil
        }

        guard let ptr = outBuf.floatChannelData?[0] else { return nil }
        return Array(UnsafeBufferPointer(start: ptr, count: Int(outBuf.frameLength)))
    }

    // MARK: - Smart LRU + Critical Memory Pressure
    private func resetLRUTimer() {
        lruEvictionTask?.cancel()
        lruEvictionTask = Task {
            do {
                try await Task.sleep(nanoseconds: lruTimeoutSeconds * 1_000_000_000)
                // executeEviction은 동기 함수 — 같은 액터 내에서 await 불필요
                if !Task.isCancelled { self.executeEviction(reason: "30분 LRU Timeout") }
            } catch {}
        }
    }

    private func setupMemoryPressureMonitor() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: [.critical], queue: .main)
        memoryPressureSource?.setEventHandler { [weak self] in
            guard let self else { return }
            Task { await self.executeEviction(reason: "시스템 Critical 메모리 압박") }
        }
        memoryPressureSource?.resume()
    }

    private func executeEviction(reason: String) {
        guard ttsModel != nil else { return }
        print("[MLXModelManager] 🚨 VRAM 퇴거 — 사유: \(reason)")
        ttsModel = nil
        referenceAudioTensors.removeAll()
    }
}
