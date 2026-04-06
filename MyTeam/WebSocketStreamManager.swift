import Foundation
import Combine
import AVFoundation

/// 스트리밍 세션을 관리하고 바이너리를 올바른 오디오 엔진으로 라우팅하는 Actor
/// (네트워크 레이스 컨디션 및 세션 혼선을 방어)
actor WebSocketStreamManager {
    static let shared = WebSocketStreamManager()
    
    // 현재 열려있는 스트림 세션
    struct ActiveStream {
        let streamId: String
        let agentId: String
        let pitch: Float
        let rate: Float
        let volume: Float
        let characterName: String
    }
    
    private var currentStream: ActiveStream?
    
    /// 컨트롤 프레임 수신 시 세션 시작
    func handleStreamStart(streamId: String, agentId: String, characterName: String, pitch: Float, rate: Float, volume: Float) {
        self.currentStream = ActiveStream(
            streamId: streamId,
            agentId: agentId,
            pitch: pitch,
            rate: rate,
            volume: volume,
            characterName: characterName
        )
        
        // 오디오 엔진에 프로필 적용 준비
        Task {
            await AudioPlaybackService.shared.prepareSession(
                streamId: streamId,
                characterName: characterName,
                pitch: pitch,
                rate: rate
            )
            print("[StreamManager] 🟢 세션 시작: \(streamId) (\(characterName))")
        }
    }
    
    /// 컨트롤 프레임 수신 시 세션 종료
    func handleStreamEnd(streamId: String) {
        if currentStream?.streamId == streamId {
            // 종료 처리는 엔진 쪽에서 자연스레 테일 처리가 되도록 전달
            Task {
                await AudioPlaybackService.shared.endSession(streamId: streamId)
            }
            self.currentStream = nil
            print("[StreamManager] 🔴 세션 종료: \(streamId)")
        }
    }
    
    /// 순수 바이너리 프레임 수신 시 현재 세션으로 라우팅
    func handleBinaryFrame(_ data: Data, format: AVAudioFormat? = nil) {
        guard let stream = currentStream else {
            print("[StreamManager] ⚠️ 활성 세션 없음. 버려진 오디오 데이터: \(data.count) bytes")
            return
        }
        
        // 백엔드와 약속된 포맷 (디폴트: 24kHz Int16 Mono) 이거나, 명시적으로 받은 포맷 사용
        let expectedFormat = format ?? getExpectedFormat()
        
        let command = PlaybackCommand(
            streamId: stream.streamId,
            pcmData: data,
            format: expectedFormat,
            characterName: stream.characterName,
            pitch: stream.pitch,
            rate: stream.rate,
            volume: stream.volume
        )
        
        Task {
            // 현재 활성 세션의 스트림으로 버퍼 밀어넣기
            await AudioPlaybackService.shared.appendRawPCM(command: command)
        }
    }
    
    /// 모든 세션 즉시 종료
    func stopAllStreams() {
        self.currentStream = nil
        Task {
            await AudioPlaybackService.shared.stopAll()
        }
    }
    
    // 디폴트 오디오 포맷 (서버-클라이언트 간의 약속)
    // - 24000Hz, 1채널(Mono), 16비트 오디오 매칭
    private nonisolated func getExpectedFormat() -> AVAudioFormat {
        return AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: false)!
    }
}
