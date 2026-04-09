import Foundation
import AVFoundation

// MARK: - PlaybackCommand
// 스트리밍 세션과 바이너리 데이터를 포함하는 오디오 재생 명령
struct PlaybackCommand: @unchecked Sendable {
    let streamId: String
    let pcmData: Data
    let format: AVAudioFormat
    
    // 이펙트 값 (음성 분리 및 커스터마이징 용)
    let characterName: String
    let pitch: Float
    let rate: Float
    let volume: Float
    
    // 🎯 Perfect Lip-Sync 페이로드
    // 이 버퍼의 PCM 데이터가 실제로 스피커에서 재생을 시작하는 순간에 트리거되는 콜백
    let textPayload: String?
    let onPlaybackStarted: (@Sendable () -> Void)?
}

// MARK: - AudioPlayable Protocol
// 재생 구현체의 공통 인터페이스.
// MLX-Swift 로컬 네이티브 전환 시에도 엔진 스왑이 가능하도록 설계.
protocol AudioPlayable: Actor {
    /// 스트림 세션을 준비하고 이펙트 파라미터를 세팅합니다.
    func prepareSession(streamId: String, characterName: String, pitch: Float, rate: Float) async
    
    /// Raw PCM 데이터를 수신하여 실시간 리샘플링 후 큐에 스케줄링합니다.
    func appendRawPCM(command: PlaybackCommand) async
    
    /// 스트림 세션을 종료하고 버퍼 플러시 혹은 테일 이펙트(Reverb 등)를 처리합니다.
    func endSession(streamId: String) async
    
    /// 현재 재생 중인 모든 오디오를 즉시 정지합니다.
    func stopAll() async
}
