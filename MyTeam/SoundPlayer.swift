import AppKit
import AVFoundation

// MARK: - SoundPlayer
// 에이전트별 효과음 재생기.
//
// [Phase 1] 시스템 NSSound 이름 사용 (Pop, Funk, Blow, Morse, Ping 등)
// [Phase 4] 커스텀 .mp3/.wav 파일로 교체 예정:
//   - dragSoundName = "alex_ouch" → Assets/Sounds/alex_ouch.mp3
//   - dropSoundName = "alex_land"  → Assets/Sounds/alex_land.mp3
//
// 시스템 사운드 이름 목록: Pop, Funk, Blow, Frog, Hero, Morse,
//                          Ping, Purr, Sosumi, Submarine, Tink

class SoundPlayer {

    // 커스텀 파일 재생용 (여러 에이전트가 동시에 소리낼 수 있도록 플레이어 배열)
    private static var players: [String: AVAudioPlayer] = [:]

    // MARK: - 에이전트별 드래그 시작 사운드
    static func playDragStart(soundName: String) {
        play(soundName: soundName)
    }

    // MARK: - 에이전트별 드래그 종료 사운드
    static func playDropEnd(soundName: String) {
        play(soundName: soundName)
    }

    // MARK: - 내부 재생 로직
    // 1순위: 번들 내 파일 (.mp3/.wav) → Phase 4에서 커스텀 파일 추가 시 자동 적용
    // 2순위: 시스템 NSSound 이름 (현재 Phase 1 기본값)
    private static func play(soundName: String) {
        // 커스텀 파일 시도 (mp3 → wav 순)
        for ext in ["mp3", "wav"] {
            if let url = Bundle.main.url(forResource: soundName, withExtension: ext) {
                let player = try? AVAudioPlayer(contentsOf: url)
                players[soundName] = player  // 메모리 유지
                player?.play()
                return
            }
        }
        // 없으면 시스템 사운드 사용
        NSSound(named: soundName)?.play()
    }
}
