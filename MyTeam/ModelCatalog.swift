import Foundation

enum ModelCatalog {
    nonisolated static let defaultTTSModelId = "aufklarer/Qwen3-TTS-12Hz-1.7B-Base-MLX-4bit"
    nonisolated static let ttsModelUserDefaultsKey = "ttsModelId"

    nonisolated static func resolvedTTSModelId() -> String {
        let stored = UserDefaults.standard.string(forKey: ttsModelUserDefaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return stored?.isEmpty == false ? stored! : defaultTTSModelId
    }

    // MARK: - Character TTS Policy

    enum FallbackMode {
        case baseVoice        // voice clone 실패 시 기본 음성으로 합성
        case disableForSession // 연속 실패 시 세션 동안 clone 비활성
        case silentSkip       // 합성 자체를 건너뜀 (극단적 케이스용)
    }

    struct CharacterTTSPolicy {
        let characterName: String
        let referenceFile: String?           // nil이면 clone 시도 안 함
        let maxConsecutiveFailures: Int      // 이 횟수 도달 시 fallbackMode 적용
        let fallbackMode: FallbackMode
    }

    /// 캐릭터별 TTS 정책 — 추후 외부 JSON/plist로 분리 예정
    static let characterPolicies: [CharacterTTSPolicy] = [
        .init(characterName: "루나", referenceFile: "루나_reference.mp3", maxConsecutiveFailures: 3, fallbackMode: .disableForSession),
        .init(characterName: "레오", referenceFile: "레오_reference.mp3", maxConsecutiveFailures: 3, fallbackMode: .disableForSession),
        .init(characterName: "래키", referenceFile: "래키_reference.mp3", maxConsecutiveFailures: 3, fallbackMode: .disableForSession),
        .init(characterName: "렉스", referenceFile: "렉스_reference.mp3", maxConsecutiveFailures: 3, fallbackMode: .disableForSession),
        .init(characterName: "모코", referenceFile: "모코_reference.mp3", maxConsecutiveFailures: 3, fallbackMode: .disableForSession),
        .init(characterName: "치코", referenceFile: "치코_reference.mp3", maxConsecutiveFailures: 3, fallbackMode: .disableForSession),
        .init(characterName: "핀",   referenceFile: "핀_reference.mp3",   maxConsecutiveFailures: 3, fallbackMode: .disableForSession),
        .init(characterName: "폴라", referenceFile: "폴라_reference.mp3", maxConsecutiveFailures: 3, fallbackMode: .disableForSession),
        .init(characterName: "케이", referenceFile: "케이_reference.mp3", maxConsecutiveFailures: 3, fallbackMode: .disableForSession),
        .init(characterName: "몽몽", referenceFile: "몽몽_reference.mp3", maxConsecutiveFailures: 3, fallbackMode: .disableForSession),
        .init(characterName: "올리버", referenceFile: "올리버_reference.mp3", maxConsecutiveFailures: 3, fallbackMode: .disableForSession),
    ]

    static func policy(for characterName: String) -> CharacterTTSPolicy? {
        characterPolicies.first { $0.characterName == characterName }
    }
}
