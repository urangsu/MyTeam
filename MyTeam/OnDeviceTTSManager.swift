import AVFoundation
import Foundation

// ============================================================
// OnDeviceTTSManager.swift
// Chatterbox HTTP 스트리밍 TTS
//
// - POST /synthesize_stream: 문장 단위 PCM 스트리밍
// - URLSessionDataDelegate: 청크 도착 즉시 scheduleBuffer
// - inputNode 완전 차단: HAL dIn 에러 방지
// - 지연 초기화: 서버 가용 시에만 오디오 엔진 시작
// ============================================================

class OnDeviceTTSManager: NSObject {
    static let shared = OnDeviceTTSManager()

    // MARK: - 오디오 엔진 (지연 초기화)
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var pitchNode: AVAudioUnitTimePitch?
    private var engineReady = false

    private(set) var isReady: Bool = false
    private(set) var isSpeaking: Bool = false

    // Chatterbox 서버 가용 여부
    private(set) var isServiceAvailable: Bool = false

    // 현재 진행 중인 합성 요청 (새 요청 시 이전 취소)
    private var currentTask: URLSessionDataTask?
    private var speakGeneration: Int = 0

    // 참조 오디오 캐시
    private var referenceAudioPathCache: [String: String] = [:]
    private var referenceAudioCache: [String: AVAudioPCMBuffer] = [:]

    // Chatterbox 출력 포맷 (24kHz mono float32)
    private let engineFormat: AVAudioFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 24000,
        channels: 1,
        interleaved: false
    )!

    // 대기 큐: isReady 전에 들어온 요청 보존
    private var pendingRequest: (text: String, characterName: String, emotion: AnimationState)?

    // 콜백 (success: 정상 재생 완료 여부)
    var onSpeakComplete: ((_ success: Bool) -> Void)?

    // WAV 데이터 콜백 — 합성 성공 시 Data 전달 (SpeechCacheManager 저장용)
    var onWavDataReady: ((_ data: Data) -> Void)?

    // MARK: - 초기화 (오디오 엔진은 아직 안 만듦)

    private override init() {
        super.init()
        // 잔존 abort 파일 제거
        try? FileManager.default.removeItem(atPath: "/tmp/mlx_tts_abort")
        Task {
            await self.checkServiceAvailability()
            await self.loadReferenceAudioAsync()
        }
    }

    // MARK: - Chatterbox 서버 가용성 확인

    private var useMLXServer = false  // MLX 서버(9998) vs Chatterbox(9999)

    func checkServiceAvailability() async {
        // 1순위: MLX TTS 서버 (port 9998, M4 GPU 가속)
        if let url = URL(string: "http://127.0.0.1:9998/health") {
            var req = URLRequest(url: url)
            req.timeoutInterval = 2.0
            if let (_, response) = try? await URLSession.shared.data(for: req),
               let http = response as? HTTPURLResponse, http.statusCode == 200 {
                isServiceAvailable = true
                useMLXServer = true
                print("[OnDeviceTTS] ✅ MLX TTS 서버 가용 (GPU 가속)")
                ensureAudioEngine()
                return
            }
        }
        // 2순위: Chatterbox 서버 (port 9999)
        if let url = URL(string: "http://127.0.0.1:9999/health") {
            var req = URLRequest(url: url)
            req.timeoutInterval = 2.0
            if let (_, response) = try? await URLSession.shared.data(for: req),
               let http = response as? HTTPURLResponse, http.statusCode == 200 {
                isServiceAvailable = true
                useMLXServer = false
                print("[OnDeviceTTS] ✅ Chatterbox 서버 가용")
                ensureAudioEngine()
                return
            }
        }
        isServiceAvailable = false
        print("[OnDeviceTTS] ℹ️ TTS 서버 없음 → 음절 WAV 폴백")
    }

    // MARK: - 오디오 엔진 (필요할 때만 초기화)

    private func ensureAudioEngine() {
        guard !engineReady else { return }

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let pitch = AVAudioUnitTimePitch()

        // ⚠️ inputNode 절대 접근 금지 → HAL dIn 에러 발생
        engine.attach(player)
        engine.attach(pitch)
        engine.connect(player, to: pitch, format: engineFormat)
        engine.connect(pitch, to: engine.mainMixerNode, format: engineFormat)
        engine.prepare()

        do {
            try engine.start()
            self.audioEngine = engine
            self.playerNode = player
            self.pitchNode = pitch
            self.engineReady = true
            print("[OnDeviceTTS] ✅ 오디오 엔진 시작 (24kHz float32)")
        } catch {
            print("[OnDeviceTTS] ❌ 오디오 엔진 실패: \(error)")
        }
    }

    // MARK: - 공유 오디오 엔진 (SpeechManager에서 사용)
    // 두 번째 AVAudioEngine 생성 시 Mac mini에서 오디오 충돌 발생
    // → 같은 엔진에 별도 플레이어 노드를 추가하여 해결

    private var extPlayer: AVAudioPlayerNode?
    private var extPitch: AVAudioUnitTimePitch?
    private var extReady = false

    private func ensureExtPlayer() {
        guard !extReady, engineReady, let engine = audioEngine else { return }
        let player = AVAudioPlayerNode()
        let pitch = AVAudioUnitTimePitch()
        engine.attach(player)
        engine.attach(pitch)
        engine.connect(player, to: pitch, format: engineFormat)
        engine.connect(pitch, to: engine.mainMixerNode, format: engineFormat)
        extPlayer = player
        extPitch = pitch
        extReady = true
        print("[OnDeviceTTS] ✅ 외부 플레이어 노드 추가")
    }

    /// 외부에서 24kHz Float32 PCM 버퍼를 재생 (SpeechManager 음절 TTS용)
    func playExternalBuffer(_ buffer: AVAudioPCMBuffer, pitch: Float = 0, volume: Float = 1.0) {
        ensureAudioEngine()
        ensureExtPlayer()
        guard extReady, let player = extPlayer, let pitchUnit = extPitch else { return }
        player.stop()
        pitchUnit.pitch = pitch
        player.volume = volume
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
    }

    func stopExternal() {
        extPlayer?.stop()
    }

    /// 엔진이 준비되었는지 확인
    var isEngineReady: Bool { engineReady }

    // MARK: - 참조 음성 로드

    private func loadReferenceAudioAsync() async {
        let characters = CharacterVoiceConfig.allCharacters
        var dir: URL? = nil

        // Bundle 우선
        if let resourceURL = Bundle.main.resourceURL {
            let c = resourceURL.appendingPathComponent("ReferenceAudio")
            if FileManager.default.fileExists(atPath: c.path) { dir = c }
        }

        // 직접 경로 폴백
        if dir == nil {
            let direct = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Desktop/MyTeam/MyTeam/Resources/ReferenceAudio")
            if FileManager.default.fileExists(atPath: direct.path) { dir = direct }
        }

        guard let dir else {
            print("[OnDeviceTTS] ℹ️ 참조음성 디렉토리 없음")
            return
        }

        var count = 0
        for name in characters {
            for ext in ["wav", "mp3"] {
                let url = dir.appendingPathComponent("\(name)_reference.\(ext)")
                guard FileManager.default.fileExists(atPath: url.path) else { continue }

                referenceAudioPathCache[name] = url.path

                // 서버 가용 시에만 버퍼 캐시 (엔진이 있어야 변환 가능)
                if engineReady, let buf = loadAudioBuffer(url: url), buf.frameLength > 0 {
                    referenceAudioCache[name] = buf
                }
                count += 1
                print("[OnDeviceTTS] ✅ \(name) 참조음성 발견")
                break
            }
        }

        isReady = count > 0
        print("[OnDeviceTTS] 로드 완료 (isReady: \(isReady), count: \(count))")

        // 대기 중인 요청 실행
        if let pending = pendingRequest {
            pendingRequest = nil
            speak(pending.text, characterName: pending.characterName, emotion: pending.emotion)
        }
    }

    private func loadAudioBuffer(url: URL) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let fmt = file.processingFormat
        let capacity = AVAudioFrameCount(file.length)
        guard capacity > 0 else { return nil }
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: capacity),
              (try? file.read(into: buf)) != nil else { return nil }
        guard buf.frameLength > 0 else { return nil }

        // 포맷이 같으면 그대로 반환
        if fmt.sampleRate == engineFormat.sampleRate &&
           fmt.channelCount == engineFormat.channelCount {
            return buf
        }

        // 포맷 변환
        guard let conv = AVAudioConverter(from: fmt, to: engineFormat) else { return nil }
        let ratio = engineFormat.sampleRate / fmt.sampleRate
        let outFrames = AVAudioFrameCount(Double(buf.frameLength) * ratio + 100)
        guard outFrames > 0 else { return nil }
        guard let out = AVAudioPCMBuffer(pcmFormat: engineFormat, frameCapacity: outFrames) else { return nil }
        var done = false
        conv.convert(to: out, error: nil) { _, status in
            if !done { done = true; status.pointee = .haveData; return buf }
            status.pointee = .endOfStream; return nil
        }
        return out.frameLength > 0 ? out : nil
    }

    // MARK: - 공개 API

    func speak(_ text: String, characterName: String, emotion: AnimationState) {
        // 서버 없으면 즉시 실패 반환 (SpeechManager가 Apple TTS로 폴백)
        guard isServiceAvailable, engineReady else {
            onSpeakComplete?(false)
            return
        }

        // 이전 합성 즉시 취소 (밀림 방지 — 최신 요청만 처리)
        currentTask?.cancel()
        currentTask = nil
        playerNode?.stop()

        let cleaned = TextSanitizer.sanitize(text)
        guard !cleaned.isEmpty else {
            onSpeakComplete?(false)
            return
        }

        // isReady 전 요청은 큐에 보존
        guard isReady else {
            pendingRequest = (cleaned, characterName, emotion)
            return
        }

        let config = CharacterVoiceConfig.emotionConfig(for: emotion)
        let trait = CharacterVoiceConfig.voiceTrait(for: characterName)
        let basePitch = (config.exaggeration - 0.5) * 400
        pitchNode?.pitch = Float(basePitch) + (Float(trait?.pitchOffset ?? 0) * 100)

        let refPath = referenceAudioPathCache[characterName]

        isSpeaking = true
        speakGeneration += 1
        let myGen = speakGeneration

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            // MainActor에서 안전하게 generation 체크
            let stillValid = await MainActor.run { self.speakGeneration == myGen }
            guard stillValid else { return }

            let ok = await self.synthesizeFullWAV(
                text: cleaned,
                refPath: refPath,
                emotionConfig: config,
                characterName: characterName
            )

            // 완료 시점 체크
            let stillValid2 = await MainActor.run { self.speakGeneration == myGen }
            guard stillValid2 else { return }

            if !ok {
                print("[OnDeviceTTS] ⚠️ 합성 실패 → 음절 WAV 폴백으로 전달")
            }

            await MainActor.run {
                self.isSpeaking = false
                self.onSpeakComplete?(ok)
            }
        }
    }

    // 긴 문장 → 짧은 청크로 분리 (TTS 품질 + 속도 최적화)
    private func splitTextForTTS(_ text: String) -> [String] {
        // 10자 이하면 분리 안 함
        if text.count <= 10 { return [text] }

        var chunks: [String] = []
        // 구분자 우선순위: 마침표, 느낌표, 물음표, 쉼표, 공백
        let separators: [Character] = [".", "!", "?", ",", " "]
        var remaining = text

        while remaining.count > 10 {
            // 8~15자 범위에서 구분자 찾기
            var splitIdx: String.Index? = nil
            let searchEnd = remaining.index(remaining.startIndex, offsetBy: min(15, remaining.count))
            let searchStart = remaining.index(remaining.startIndex, offsetBy: min(6, remaining.count))

            for sep in separators {
                if let idx = remaining[searchStart..<searchEnd].lastIndex(of: sep) {
                    splitIdx = remaining.index(after: idx)
                    break
                }
            }

            // 구분자 없으면 10자에서 강제 분리
            if splitIdx == nil {
                splitIdx = remaining.index(remaining.startIndex, offsetBy: min(10, remaining.count))
            }

            let chunk = String(remaining[..<splitIdx!]).trimmingCharacters(in: .whitespaces)
            if !chunk.isEmpty { chunks.append(chunk) }
            remaining = String(remaining[splitIdx!...]).trimmingCharacters(in: .whitespaces)
        }

        if !remaining.isEmpty { chunks.append(remaining) }
        return chunks
    }

    func stop() {
        let wasSpeaking = isSpeaking
        isSpeaking = false
        speakGeneration += 1
        currentTask?.cancel()
        currentTask = nil
        playerNode?.stop()
        playerNode?.reset()
        // 합성 진행 중이었을 때만 abort 신호
        if wasSpeaking && useMLXServer {
            FileManager.default.createFile(atPath: "/tmp/mlx_tts_abort", contents: nil)
        }
    }

    // MARK: - 합성 전용 (재생 분리) — speakChunk용

    /// WAV 데이터만 합성하고 재생은 하지 않음 (SpeechManager.speakChunk 전용)
    /// 반환된 Data를 playWithEffects()에 넘겨 피치/속도 이펙트 적용 후 재생
    func synthesizeOnly(_ text: String, characterName: String,
                         completion: @escaping (Data?) -> Void) {
        guard isServiceAvailable else { completion(nil); return }

        let sanitized = TextSanitizer.sanitize(text)
        guard !sanitized.isEmpty else { completion(nil); return }

        let req: URLRequest

        if useMLXServer {
            let encoded = sanitized.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sanitized
            let charEnc = characterName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? characterName
            guard let url = URL(string: "http://127.0.0.1:9998/synthesize?text=\(encoded)&character=\(charEnc)") else {
                completion(nil); return
            }
            var r = URLRequest(url: url)
            r.timeoutInterval = 30.0
            req = r
        } else {
            guard let url = URL(string: "http://127.0.0.1:9999/synthesize") else {
                completion(nil); return
            }
            let refPath = referenceAudioPathCache[characterName]
            let config = CharacterVoiceConfig.emotionConfig(for: .speaking)
            var body: [String: Any] = [
                "text": sanitized,
                "exaggeration": config.exaggeration,
                "cfg_weight": config.cfg_weight,
                "language_id": "ko"
            ]
            if let p = refPath { body["ref_audio_path"] = p }
            guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
                completion(nil); return
            }
            var r = URLRequest(url: url)
            r.httpMethod = "POST"
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = jsonData
            r.timeoutInterval = 60.0
            req = r
        }

        print("[OnDeviceTTS] 🎙️ synthesizeOnly: \(characterName) '\(sanitized.prefix(20))'")

        URLSession.shared.dataTask(with: req) { data, response, error in
            guard let data = data,
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  data.count > 100 else {
                print("[OnDeviceTTS] ❌ synthesizeOnly 실패: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                completion(nil)
                return
            }
            print("[OnDeviceTTS] ✅ synthesizeOnly 완료: \(data.count) bytes")
            completion(data)
        }.resume()
    }

    // MARK: - 비스트리밍 합성 (완전한 WAV 반환)

    private func synthesizeFullWAV(
        text: String,
        refPath: String?,
        emotionConfig: CharacterVoiceConfig.EmotionConfig,
        characterName: String
    ) async -> Bool {

        let req: URLRequest

        if useMLXServer {
            // MLX TTS 서버 (GET, query params)
            let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
            let charEncoded = characterName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? characterName
            guard let url = URL(string: "http://127.0.0.1:9998/synthesize?text=\(encoded)&character=\(charEncoded)") else { return false }
            var r = URLRequest(url: url)
            r.timeoutInterval = 30.0
            req = r
            print("[OnDeviceTTS] 🧠 MLX GPU 합성: \(characterName)")
        } else {
            // Chatterbox 서버 (POST, JSON body)
            guard let url = URL(string: "http://127.0.0.1:9999/synthesize") else { return false }
            var body: [String: Any] = [
                "text": text,
                "exaggeration": emotionConfig.exaggeration,
                "cfg_weight": emotionConfig.cfg_weight,
                "language_id": "ko"
            ]
            if let p = refPath { body["ref_audio_path"] = p }
            guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return false }
            var r = URLRequest(url: url)
            r.httpMethod = "POST"
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = jsonData
            r.timeoutInterval = 60.0
            req = r
            print("[OnDeviceTTS] 🌐 Chatterbox 합성: \(characterName)")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                print("[OnDeviceTTS] ❌ 합성 HTTP 에러: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return false
            }

            guard data.count > 100 else {
                print("[OnDeviceTTS] ❌ 합성 데이터 너무 작음: \(data.count) bytes")
                return false
            }

            print("[OnDeviceTTS] ✅ 합성 성공: \(data.count) bytes")

            // WAV 데이터 콜백 (캐시 저장용)
            onWavDataReady?(data)

            // WAV 데이터를 AVAudioPlayer로 재생 (AVAudioEngine 우회)
            let player = try AVAudioPlayer(data: data)
            player.volume = 1.0
            player.play()

            // 재생 완료 대기
            while player.isPlaying {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            return true

        } catch {
            print("[OnDeviceTTS] ❌ 합성 실패: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - 스트리밍 요청 (레거시)

    private func streamSpeak(
        text: String,
        refPath: String?,
        emotionConfig: CharacterVoiceConfig.EmotionConfig,
        characterName: String
    ) async -> Bool {

        guard let url = URL(string: "http://127.0.0.1:9999/synthesize_stream") else { return false }
        guard let engine = audioEngine, let player = playerNode else { return false }

        var body: [String: Any] = [
            "text": text,
            "exaggeration": emotionConfig.exaggeration,
            "cfg_weight": emotionConfig.cfg_weight,
            "language_id": "ko"
        ]
        if let p = refPath { body["ref_audio_path"] = p }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return false }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = jsonData
        req.timeoutInterval = 180.0

        print("[OnDeviceTTS] 🌐 스트리밍 요청: \(characterName)")

        return await withCheckedContinuation { continuation in
            let delegate = StreamingAudioDelegate(
                playerNode: player,
                audioEngine: engine,
                format: self.engineFormat,
                onComplete: { success in
                    continuation.resume(returning: success)
                }
            )
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let task = session.dataTask(with: req)
            task.resume()
        }
    }

    // MARK: - 폴백 버퍼 재생

    private func playBuffer(_ buffer: AVAudioPCMBuffer) async {
        guard buffer.frameLength > 0 else { return }
        guard let engine = audioEngine, let player = playerNode else { return }
        if !engine.isRunning { try? engine.start() }
        player.stop()
        await player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
        let dur = Double(buffer.frameLength) / 24000.0
        try? await Task.sleep(nanoseconds: UInt64(dur * 1_000_000_000))
    }
}

// MARK: - 스트리밍 URLSessionDataDelegate

final class StreamingAudioDelegate: NSObject, URLSessionDataDelegate {

    private let playerNode: AVAudioPlayerNode
    private let audioEngine: AVAudioEngine
    private let format: AVAudioFormat
    private let onComplete: (Bool) -> Void

    private var buffer = Data()
    private var isPlaying = false
    private var hasError = false

    private let firstChunkBytes = 1024
    private let followChunkBytes = 4096

    init(
        playerNode: AVAudioPlayerNode,
        audioEngine: AVAudioEngine,
        format: AVAudioFormat,
        onComplete: @escaping (Bool) -> Void
    ) {
        self.playerNode = playerNode
        self.audioEngine = audioEngine
        self.format = format
        self.onComplete = onComplete
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !data.isEmpty else { return }
        buffer.append(data)

        let threshold = isPlaying ? followChunkBytes : firstChunkBytes
        if buffer.count >= threshold {
            flushBuffer()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            let nsErr = error as NSError
            if nsErr.code != NSURLErrorCancelled {
                print("[Streaming] ❌ 에러: \(error.localizedDescription)")
                hasError = true
            }
        } else {
            if !buffer.isEmpty { flushBuffer() }
        }

        let delay = isPlaying ? 0.5 : 0.0
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.onComplete(!self.hasError)
        }
    }

    private func flushBuffer() {
        let data = buffer
        buffer = Data()

        guard !data.isEmpty else { return }
        guard let pcmBuffer = rawPCMToBuffer(data), pcmBuffer.frameLength > 0 else { return }

        if !audioEngine.isRunning {
            try? audioEngine.start()
        }

        playerNode.scheduleBuffer(pcmBuffer, at: nil, options: [])

        if !isPlaying {
            isPlaying = true
            playerNode.play()
        }
    }

    private func rawPCMToBuffer(_ data: Data) -> AVAudioPCMBuffer? {
        let frameCount = data.count / MemoryLayout<Float>.size
        guard frameCount > 0 else { return nil }

        guard let pcmBuf = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(frameCount)
        ) else { return nil }

        pcmBuf.frameLength = AVAudioFrameCount(frameCount)

        guard let channelData = pcmBuf.floatChannelData?.pointee else { return nil }

        data.withUnsafeBytes { rawPtr in
            guard let floatPtr = rawPtr.baseAddress?.assumingMemoryBound(to: Float.self) else { return }
            channelData.update(from: floatPtr, count: frameCount)
        }

        return pcmBuf
    }
}
