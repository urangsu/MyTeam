import Foundation
import AVFoundation

actor AudioPlaybackService: AudioPlayable {
    static let shared = AudioPlaybackService()
    
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitchNode = AVAudioUnitTimePitch()
    private var engineFormat: AVAudioFormat!
    
    private var currentActiveStreamId: String? = nil
    
    var isCurrentlyPlaying: Bool { return playerNode.isPlaying }
    
    private init() {
        setupEngine()
    }
    
    private func setupEngine() {
        engine.attach(playerNode)
        engine.attach(timePitchNode)
        
        // 믹서 노드의 기본 포맷을 엔진의 공통 포맷으로 기준 잡습니다. 
        // 맥 환경에서는 보통 44.1kHz 또는 48kHz Stereo가 됩니다.
        engineFormat = engine.mainMixerNode.outputFormat(forBus: 0)
        
        engine.connect(playerNode, to: timePitchNode, format: engineFormat)
        engine.connect(timePitchNode, to: engine.mainMixerNode, format: engineFormat)
        
        do {
            try engine.start()
            print("[AudioPlayback] 엔진 시작 완료. 기준 포맷: \(engineFormat!)")
        } catch {
            print("[AudioPlayback] 🚨 스피커 엔진 시작 실패: \(error)")
        }
    }
    
    // MARK: - Optimization & Tracking State
    private var converters: [String: AVAudioConverter] = [:]
    private var queuedBufferCount: Int = 0
    private let playbackStartThreshold: Int = 2 // Jitter 방어를 위한 최소 버퍼 조각 갯수 (약 60~100ms)
    
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
                print("[AudioPlayback] 🚨 AVAudioConverter 생성 실패")
                return nil
            }
            
            let ratio = dstFormat.sampleRate / srcFormat.sampleRate
            let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio) + 1024
            guard let output = AVAudioPCMBuffer(pcmFormat: dstFormat, frameCapacity: capacity) else { return nil }
            
            var error: NSError?
            var inputConsumed = false
            
            converter.convert(to: output, error: &error) { packetCount, outStatus in
                if !inputConsumed {
                    inputConsumed = true
                    outStatus.pointee = .haveData
                    return input
                } else {
                    outStatus.pointee = .noDataNow
                    return nil
                }
            }
            
            if let err = error {
                print("[AudioPlayback] 🚨 포맷 변환 에러: \(err)")
                return nil
            }
            return output
        }
    }
    
    /// 네트워크나 TTS 생성기에서 들어온 Data를 안전하게 리샘플링하여 스케줄
    func appendRawPCM(command: PlaybackCommand) {
        autoreleasepool {
            guard command.streamId == currentActiveStreamId else { return }
            
            let data = command.pcmData
            guard !data.isEmpty else { return }
            let sourceFormat = command.format
            
            // 1. Data -> AVAudioPCMBuffer 구조 복원
            guard let sourceBuffer = data.toAVAudioPCMBuffer(format: sourceFormat) else { return }
            
            // 2. 리샘플링
            guard let outBuffer = convertBuffer(sourceBuffer, from: sourceFormat, to: engineFormat) else { return }
            
            // 3. 볼륨
            playerNode.volume = command.volume
            
            // 4. 스케줄링 (엔진 백그라운드 틱과 연결)
            playerNode.scheduleBuffer(outBuffer, at: nil, options: []) { [weak self] in
                // 버퍼가 소진될 때 (Underrun 우려 시) 무음 패딩을 넣는 장치 등은 여기서 제어 가능합니다.
                // 현재는 Apple 가이드라인에 따라 schedule 처리를 위임하되, 재생 완료 이벤트를 추적만 합니다.
                Task { [weak self] in
                    guard let self else { return }
                    await self.decrementBufferCount()
                }
            }
            queuedBufferCount += 1
            
            // 5. Jitter Pre-buffering: 임계점까지 도달하면 비로소 엔진 start & 재생
            if !playerNode.isPlaying && queuedBufferCount >= playbackStartThreshold {
                if !engine.isRunning { try? engine.start() }
                playerNode.play()
            }
        }
    }
    
    private func decrementBufferCount() {
        queuedBufferCount = max(0, queuedBufferCount - 1)
    }
    
    func endSession(streamId: String) {
        if currentActiveStreamId == streamId {
            // Teardown: 재생 노드를 중지하고 분리(Detach)하여 엔진 무리 및 메모리 릭 방지
            playerNode.stop()
            engine.disconnectNodeOutput(playerNode)
            engine.disconnectNodeOutput(timePitchNode)
            engine.detach(playerNode)
            engine.detach(timePitchNode)
            
            currentActiveStreamId = nil
            queuedBufferCount = 0
            
            // 사용을 다한 재사용 컨버터들을 정리(Evict)
            converters.removeAll()
            print("[AudioPlayback] 🧹 세션(\(streamId)) 종료 및 오디오 노드 Detach, 컨버터 풀 Evict 완료")
        }
    }
    
    func prepareSession(streamId: String, characterName: String, pitch: Float, rate: Float) {
        if currentActiveStreamId != streamId {
            playerNode.stop()
            
            // 기존 노드가 엔진에 안 붙어있을 수 있으므로 재연결 로직 가동
            if playerNode.engine == nil {
                engine.attach(playerNode)
                engine.attach(timePitchNode)
                engine.connect(playerNode, to: timePitchNode, format: engineFormat)
                engine.connect(timePitchNode, to: engine.mainMixerNode, format: engineFormat)
            }
            
            currentActiveStreamId = streamId
            queuedBufferCount = 0
            
            // 새 세션용 컨버터 풀 초기화
            converters.removeAll()
        }
        
        timePitchNode.pitch = pitch
        timePitchNode.rate = rate
    }

    func playStream(streamId: String, stream: AsyncStream<Data>, characterName: String, pitch: Float, rate: Float) async {
        // 1. 세션 환경 구성
        prepareSession(streamId: streamId, characterName: characterName, pitch: pitch, rate: rate)
        
        let format = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)! // HiFiGAN 출력 기준 포맷
        
        // 2. 우아한 백프레셔 스트림 구독 (for await)
        for await pcmData in stream {
            // Task 취소 시 스트림 루프 즉시 정지
            guard !Task.isCancelled else { break }
            
            let command = PlaybackCommand(
                streamId: streamId,
                pcmData: pcmData,
                format: format,
                characterName: characterName,
                pitch: pitch,
                rate: rate,
                volume: 1.0
            )
            await appendRawPCM(command: command)
        }
        
        // 3. 스트림 종료 후 Teardown (선택사항, 필요시 일정 대기 후 종료 가능)
        // endSession(streamId: streamId) 
    }

    func stopAll() {

        playerNode.stop()
        if playerNode.engine != nil {
            engine.disconnectNodeOutput(playerNode)
            engine.disconnectNodeOutput(timePitchNode)
            engine.detach(playerNode)
            engine.detach(timePitchNode)
        }
        currentActiveStreamId = nil
        queuedBufferCount = 0
        converters.removeAll()
    }

}

// MARK: - Data to AVAudioPCMBuffer Extension
extension Data {
    func toAVAudioPCMBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
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
