import Foundation
@preconcurrency import AVFoundation

actor AudioPlaybackService: AudioPlayable {
    static let shared = AudioPlaybackService()

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitchNode = AVAudioUnitTimePitch()
    private var engineFormat: AVAudioFormat?
    private var isGraphConfigured = false

    private var currentActiveStreamId: String? = nil

    private final class PlaybackCompletion: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Bool, Never>?
        private var pendingResult: Bool?
        private var timeoutTask: Task<Void, Never>?

        func wait(timeoutNanoseconds: UInt64) async -> Bool {
            await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    lock.lock()
                    if let pendingResult {
                        lock.unlock()
                        continuation.resume(returning: pendingResult)
                        return
                    }
                    self.continuation = continuation
                    timeoutTask = Task { [weak self] in
                        try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                        self?.resolve(false)
                    }
                    lock.unlock()
                }
            } onCancel: {
                self.resolve(false)
            }
        }

        func resolve(_ result: Bool) {
            lock.lock()
            guard pendingResult == nil else {
                lock.unlock()
                return
            }
            pendingResult = result
            let continuation = continuation
            self.continuation = nil
            let timeoutTask = timeoutTask
            self.timeoutTask = nil
            lock.unlock()

            timeoutTask?.cancel()
            continuation?.resume(returning: result)
        }
    }

    var isCurrentlyPlaying: Bool { return playerNode.isPlaying }

    private init() {}

    @discardableResult
    private func ensureEngineReady() -> Bool {
        if !isGraphConfigured {
            configureEngineGraph()
        }

        guard let format = engineFormat else {
            AppLog.error("[AudioPlayback] engineFormat nil — engine graph is not ready")
            return false
        }

        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                AppLog.error("[AudioPlayback] engine.start() 실패: \(error)")
                return false
            }
        }

        if !format.sampleRate.isFinite || format.sampleRate <= 0 {
            AppLog.error("[AudioPlayback] invalid engine format: \(format)")
            return false
        }
        return true
    }

    private func configureEngineGraph() {
        guard !isGraphConfigured else { return }

        engine.attach(playerNode)
        engine.attach(timePitchNode)

        // 믹서 노드의 기본 포맷을 엔진의 공통 포맷으로 기준 잡습니다.
        // 맥 환경에서는 보통 44.1kHz 또는 48kHz Stereo가 됩니다.
        engineFormat = engine.mainMixerNode.outputFormat(forBus: 0)

        guard let format = engineFormat else {
            AppLog.error("[AudioPlayback] 엔진 기준 포맷을 확인하지 못했습니다.")
            return
        }

        engine.connect(playerNode, to: timePitchNode, format: format)
        engine.connect(timePitchNode, to: engine.mainMixerNode, format: format)
        isGraphConfigured = true
        AppLog.info("[AudioPlayback] 엔진 graph 구성 완료. 기준 포맷: \(format)")
    }

    // MARK: - Optimization & Tracking State
    private var converters: [String: AVAudioConverter] = [:]
    private var queuedBufferCount: Int = 0
    func getQueuedBufferCount() -> Int { return queuedBufferCount }
    private let playbackStartThreshold: Int = 1 // threshold=1: 첫 청크 도착 즉시 재생 (짧은 문장 누락 방지)

    // MARK: - Core Resampling Logic (Reuse + Autoreleasepool)
    private func convertBuffer(_ input: AVAudioPCMBuffer, from srcFormat: AVAudioFormat, to dstFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        return autoreleasepool { () -> AVAudioPCMBuffer? in
            // 포맷 일치 시 패스
            if srcFormat.sampleRate == dstFormat.sampleRate && srcFormat.channelCount == dstFormat.channelCount {
                return input
            }

            let formatKey = "\(srcFormat.description)_to_\(dstFormat.description)"
            let converter: AVAudioConverter
            if let cached = converters[formatKey] {
                converter = cached
            } else if let newConverter = AVAudioConverter(from: srcFormat, to: dstFormat) {
                converters[formatKey] = newConverter
                converter = newConverter
            } else {
                AppLog.error("[AudioPlayback] AVAudioConverter 생성 실패")
                return nil
            }

            let ratio = dstFormat.sampleRate / srcFormat.sampleRate
            let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio) + 1024
            guard let output = AVAudioPCMBuffer(pcmFormat: dstFormat, frameCapacity: capacity) else { return nil }

            var error: NSError?
            class InputState: @unchecked Sendable { var consumed = false }
            let state = InputState()

            converter.convert(to: output, error: &error) { packetCount, outStatus in
                if !state.consumed {
                    state.consumed = true
                    outStatus.pointee = .haveData
                    return input
                } else {
                    outStatus.pointee = .noDataNow
                    return nil
                }
            }

            if let err = error {
                AppLog.error("[AudioPlayback] 포맷 변환 에러: \(err)")
                return nil
            }
            return output
        }
    }

    /// 네트워크나 TTS 생성기에서 들어온 Data를 안전하게 리샘플링하여 스케줄
    func appendRawPCM(command: PlaybackCommand) {
        guard ensureEngineReady(), let format = engineFormat else { return }

        // onPlaybackStarted 클로저를 actor 격리 컨텍스트 밖으로 먼저 캡처
        let lipSyncCallback: (@MainActor @Sendable () -> Void)? = command.onPlaybackStarted

        autoreleasepool {
            guard command.streamId == currentActiveStreamId else {
                // ⚠️ Silent drop diagnostic: 무음 이슈 추적용
                AppLog.info("[AudioPlayback] 🚫 버퍼 드랍: streamId=\(command.streamId.prefix(12)) active=\(currentActiveStreamId?.prefix(12) ?? "nil") (\(command.pcmData.count)B 버려짐)")
                return
            }

            let data = command.pcmData
            guard !data.isEmpty else {
                AppLog.info("[AudioPlayback] 🚫 빈 버퍼 드랍: streamId=\(command.streamId.prefix(12))")
                return
            }
            let sourceFormat = command.format

            // 1. Data -> AVAudioPCMBuffer 구조 복원
            guard let sourceBuffer = data.toAVAudioPCMBuffer(format: sourceFormat) else { return }

            // 2. 리샘플링
            guard let outBuffer = convertBuffer(sourceBuffer, from: sourceFormat, to: format) else { return }

            // 3. 볼륨
            playerNode.volume = command.volume

            // 4. 버퍼 스케줄링
            let wasAlreadyPlaying = playerNode.isPlaying
            playerNode.scheduleBuffer(outBuffer, at: nil, options: []) { [weak self] in
                Task(priority: .userInitiated) { [weak self] in
                    guard let self else { return }
                    await self.decrementBufferCount()
                }
            }
            queuedBufferCount += 1

            // 5. Jitter Pre-buffering: 임계점까지 도달하면 비로소 엔진 start & 재생
            if !playerNode.isPlaying && queuedBufferCount >= playbackStartThreshold {
                playerNode.play()
                AppLog.info("[AudioPlayback] ▶️ 재생 개시 (streamId=\(command.streamId.prefix(12)), queuedBuffers=\(queuedBufferCount), engineRunning=\(engine.isRunning), playerPlaying=\(playerNode.isPlaying))")
            }

            // 🎯 Perfect Lip-Sync: 첫 버퍼가 재생 큐에 등록되는 찰나에 UI 말풍선 트리거
            // wasAlreadyPlaying=false → 이 버퍼가 재생 개시 버퍼 → 텍스트 표시 타이밍 정확
            if !wasAlreadyPlaying, let callback = lipSyncCallback {
                Task(priority: .userInitiated) { @MainActor in callback() }
            }
        }
    }

    private func decrementBufferCount() {
        queuedBufferCount = max(0, queuedBufferCount - 1)
    }

    private func resetPlayerQueueIfNeeded(reason: String) {
        let hadQueuedAudio = queuedBufferCount > 0
        let wasPlaying = playerNode.isPlaying

        guard wasPlaying || hadQueuedAudio else {
            queuedBufferCount = 0
            return
        }

        playerNode.stop()
        playerNode.reset()
        queuedBufferCount = 0
        AppLog.info("[AudioPlayback] player reset: \(reason), wasPlaying=\(wasPlaying), hadQueuedAudio=\(hadQueuedAudio)")
    }

    func endSession(streamId: String) {
        if currentActiveStreamId == streamId {
            resetPlayerQueueIfNeeded(reason: "endSession")

            currentActiveStreamId = nil

            // 사용을 다한 재사용 컨버터들을 정리(Evict)
            converters.removeAll()
            AppLog.info("[AudioPlayback] 세션(\(streamId)) 종료: player reset, queue clear, converter pool evict")
        }
    }

    func prepareSession(streamId: String, characterName: String, pitch: Float, rate: Float) {
        prepareSession(streamId: streamId, characterName: characterName, pitch: pitch, rate: rate, engineAlreadyReady: false)
    }

    private func prepareSession(
        streamId: String,
        characterName: String,
        pitch: Float,
        rate: Float,
        engineAlreadyReady: Bool
    ) {
        if !engineAlreadyReady {
            guard ensureEngineReady() else { return }
        }

        if currentActiveStreamId != streamId {
            resetPlayerQueueIfNeeded(reason: "session switch")

            currentActiveStreamId = streamId

            // 새 세션용 컨버터 풀 초기화
            converters.removeAll()
        }

        timePitchNode.pitch = pitch
        timePitchNode.rate = rate
    }

    func playStream(
        streamId: String,
        stream: AsyncStream<Data>,
        characterName: String,
        pitch: Float,
        rate: Float,
        textPayload: String? = nil,
        onPlaybackStarted: (@MainActor @Sendable () -> Void)? = nil
    ) async {
        let format = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)! // HiFiGAN 출력 기준 포맷

        // 🔑 핵심 Fix: prepareSession을 스트림 시작 시가 아니라 첫 PCM chunk 도착 시에 호출.
        //   이유: MLX 추론이 완료된 후에야 첫 chunk가 도착하기 때문에,
        //         "추론 완료 순서"대로 세션이 교체됨.
        //   기존: playStream 진입 즉시 prepareSession → 아직 추론 중인데 active 교체 → 이전 PCM 100% 드랍
        var sessionReady = false
        var isFirstChunk = true

        // 백프레셔 스트림 구독 (for await)
        for await pcmData in stream {
            guard !Task.isCancelled else { break }

            // 첫 데이터 도착 = 추론 완료 시점. 이때 세션 교체.
            if !sessionReady {
                prepareSession(streamId: streamId, characterName: characterName, pitch: pitch, rate: rate)
                sessionReady = true
                AppLog.info("[AudioPlayback] 🎬 세션 시작 (추론 완료 시점, streamId=\(streamId.prefix(12)), active=\(currentActiveStreamId?.prefix(12) ?? "nil"))")
            }

            let command = PlaybackCommand(
                streamId: streamId,
                pcmData: pcmData,
                format: format,
                characterName: characterName,
                pitch: pitch,
                rate: rate,
                volume: 1.0,
                // 🎯 첫 번째 청크에만 Lip-Sync 콜백 탑재
                textPayload: isFirstChunk ? textPayload : nil,
                onPlaybackStarted: isFirstChunk ? onPlaybackStarted : nil
            )
            isFirstChunk = false
            appendRawPCM(command: command)
        }

        // 🔊 스트림 종료 후 안전망: 아직 playerNode가 play 안 됐으면 강제 시작
        // (짧은 문장 → threshold 미달 → 재생 안 되는 버그 방어)
        if !playerNode.isPlaying && queuedBufferCount > 0 {
            guard ensureEngineReady() else { return }
            playerNode.play()
            AppLog.info("[AudioPlayback] ⚡ 스트림 종료 후 강제 재생 시작 (queuedBuffers=\(queuedBufferCount))")
        }
    }

    // MARK: - Round 257TTS-PLAYBACK: Float samples 직접 재생 (Supertonic3 전용)

    /// Supertonic3ONNXRunner 합성 결과([Float] wavSamples)를 AVAudioEngine을 통해 직접 재생.
    /// - Parameters:
    ///   - samples: Float [-1, 1] PCM samples (Supertonic3 출력)
    ///   - sampleRate: 출력 샘플레이트 (보통 44100)
    ///   - streamId: 세션 식별자 (UUID().uuidString 권장)
    ///   - characterName: 로그용 캐릭터 이름
    ///   - pitch: AVAudioUnitTimePitch.pitch (cents). clamp: -300~+360. default 0.0
    ///   - rate: AVAudioUnitTimePitch.rate 배율. clamp: 0.90~1.14. default 1.0
    ///   - onPlaybackStarted: playerNode.play() 이후 MainActor에서 호출되는 콜백 (nil 가능)
    @discardableResult
    func playFloatSamples(
        samples: [Float],
        sampleRate: Int,
        streamId: String,
        characterName: String,
        pitch: Float = 0.0,
        rate: Float = 1.0,
        onPlaybackStarted: (@MainActor @Sendable () -> Void)? = nil
    ) async -> Bool {
        guard !samples.isEmpty else {
            AppLog.info("[AudioPlayback] playFloatSamples: empty samples → skip")
            return false
        }
        guard ensureEngineReady() else { return false }
        guard let ef = engineFormat else {
            AppLog.error("[AudioPlayback] playFloatSamples: engineFormat nil — engine not ready")
            return false
        }

        // 1. 소스 포맷: standardFormat(44.1kHz, 1ch, float32 non-interleaved)
        guard let srcFormat = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1) else {
            AppLog.error("[AudioPlayback] playFloatSamples: 소스 포맷 생성 실패")
            return false
        }
        let frameCount = AVAudioFrameCount(samples.count)

        // 2. AVAudioPCMBuffer 생성 + Float 샘플 복사
        guard let srcBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: frameCount) else {
            AppLog.error("[AudioPlayback] playFloatSamples: PCM 버퍼 할당 실패")
            return false
        }
        srcBuffer.frameLength = frameCount
        guard let channelData = srcBuffer.floatChannelData else {
            AppLog.error("[AudioPlayback] playFloatSamples: floatChannelData nil")
            return false
        }
        channelData[0].update(from: samples, count: Int(frameCount))

        // 3. 세션 준비 (currentActiveStreamId 설정; graph 재구성 없음)
        // Round 258TTS: pitch/rate clamp 적용 후 prepareSession에 전달
        prepareSession(streamId: streamId, characterName: characterName,
                       pitch: clampedPitch(pitch), rate: clampedRate(rate), engineAlreadyReady: true)

        // 4. 엔진 포맷으로 변환 (모노→스테레오, 샘플레이트 변환 포함)
        guard let outBuffer = convertBuffer(srcBuffer, from: srcFormat, to: ef) else {
            AppLog.error("[AudioPlayback] playFloatSamples: 포맷 변환 실패")
            return false
        }

        // 5. 버퍼 스케줄링
        playerNode.volume = 1.0
        let completion = PlaybackCompletion()
        playerNode.scheduleBuffer(outBuffer, at: nil, options: [], completionCallbackType: .dataPlayedBack) { [weak self] callbackType in
            completion.resolve(callbackType == .dataPlayedBack)
            Task(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                await self.decrementBufferCount()
            }
        }
        queuedBufferCount += 1

        // 6. 재생 — readiness는 함수 초반 1회 확인했고, 콜백은 playerNode.play() 이후에만 호출
        if !playerNode.isPlaying {
            playerNode.play()
            AppLog.info("[AudioPlayback] ▶️ playFloatSamples 재생 시작 "
                + "(streamId=\(streamId.prefix(12)), frames=\(frameCount), sr=\(sampleRate)Hz, char=\(characterName))")
        }

        // 7. playerNode.play() 이후 콜백 — 립싱크 원칙 준수
        if let cb = onPlaybackStarted {
            await MainActor.run { cb() }
        }
        let durationSeconds = Double(outBuffer.frameLength) / max(1, outBuffer.format.sampleRate)
        let timeoutSeconds = min(120, max(3, durationSeconds + 2))
        let didFinish = await completion.wait(timeoutNanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
        if !didFinish {
            AppLog.warning("[AudioPlayback] playFloatSamples did not reach dataPlayedBack "
                + "(streamId=\(streamId.prefix(12)), timeout=\(timeoutSeconds)s)")
        }
        return didFinish
    }

    // MARK: - Round 258TTS: pitch/rate clamp helpers
    // 범위: VoicePlaybackStyle.clamped와 동일 (SpeechManager.swift 참고)
    private func clampedPitch(_ p: Float) -> Float { min(360, max(-300, p)) }
    private func clampedRate(_ r: Float) -> Float { min(1.14, max(0.90, r)) }

    func stopAll() {

        resetPlayerQueueIfNeeded(reason: "stopAll")
        currentActiveStreamId = nil
        converters.removeAll()
        AppLog.info("[AudioPlayback] stopAll: player reset, queue clear, engine graph kept attached")
    }

    /// 앱 종료 전용 즉시 정지.
    /// `engine.stop()`을 명시적으로 호출해 CoreAudio 렌더 스레드를 즉시 중단시킨다.
    /// 렌더 콜백이 in-flight인 상태로 Swift 객체가 해제되면 AVAudioNode(ObjC) 메시지 접근 크래시 발생 — 이를 방지.
    func stopEngineForTermination() {
        playerNode.stop()
        if engine.isRunning { engine.stop() }
        if playerNode.engine != nil {
            engine.disconnectNodeOutput(playerNode)
            engine.disconnectNodeOutput(timePitchNode)
            engine.detach(playerNode)
            engine.detach(timePitchNode)
        }
        isGraphConfigured = false
        engineFormat = nil
        currentActiveStreamId = nil
        queuedBufferCount = 0
        converters.removeAll()
    }

}

// MARK: - Data to AVAudioPCMBuffer Extension
extension Data {
    nonisolated func toAVAudioPCMBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let streamDesc = format.streamDescription.pointee
        let bytesPerFrame = streamDesc.mBytesPerFrame
        guard bytesPerFrame > 0 else { return nil }

        let frameCapacity = UInt32(self.count) / bytesPerFrame
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else { return nil }

        buffer.frameLength = frameCapacity
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers

        self.withUnsafeBytes { bufferPointer in
            guard let baseAddress = bufferPointer.baseAddress else { return }
            audioBuffer.mData?.copyMemory(from: baseAddress, byteCount: self.count)
        }
        return buffer
    }
}
