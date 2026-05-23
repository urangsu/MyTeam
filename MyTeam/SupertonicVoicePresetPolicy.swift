import Foundation

// MARK: - SupertonicVoicePresetPolicy
// Round 258B-TTS-EMOTION-AUDIT: emotion-aware pitch/rate/speed API 추가.
//
// base API: pitch/rate/speed(for:) — 기본값 반환 (emotion nil 위임).
// emotion-aware API: pitch/rate/speed(for:emotion:) — emotion에 따라 boost 적용.
//   - neutral: base 값 그대로
//   - careful: base + min(0, boost) — 음수 boost만 적용 (더 조심스럽게)
//   - friendly, confident, excited: base + boost 전체 적용
//   - animalCrossing: base + animalCrossingBoost (강한 모드, 기본 미사용)
// emotionStyle(for:): 캐릭터 기본 감정 반환 (SpeechManager에서 사용)

enum SupertonicVoicePresetPolicy {

    // MARK: - Preset

    /// Returns the Supertonic3 voice preset for the given agentID.
    static func preset(for agentID: String?) -> String {
        CharacterVoiceProfileCatalog.profile(for: agentID).preset
    }

    // MARK: - Emotion Style

    /// Returns the default emotion style for the given agentID.
    static func emotionStyle(for agentID: String?) -> SupertonicEmotionStyle {
        CharacterVoiceProfileCatalog.profile(for: agentID).defaultEmotionStyle
    }

    // MARK: - Base API (emotion = nil → base 값)

    /// Returns the pitch (cents) for the given agentID using base value.
    static func pitch(for agentID: String?) -> Float {
        pitch(for: agentID, emotion: nil)
    }

    /// Returns the playback rate for the given agentID using base value.
    static func rate(for agentID: String?) -> Float {
        rate(for: agentID, emotion: nil)
    }

    /// Returns the synthesis speed for the given agentID using base value.
    static func speed(for agentID: String?) -> Float {
        speed(for: agentID, emotion: nil)
    }

    // MARK: - Emotion-Aware API

    /// Returns pitch (cents) adjusted for the given emotion style.
    static func pitch(for agentID: String?, emotion: SupertonicEmotionStyle?) -> Float {
        let p = CharacterVoiceProfileCatalog.profile(for: agentID)
        guard let emotion else { return p.basePitch }
        switch emotion {
        case .neutral:
            return p.basePitch
        case .careful:
            return p.basePitch + min(0, p.emotionPitchBoost)
        case .friendly, .confident, .excited:
            return p.basePitch + p.emotionPitchBoost
        case .animalCrossing:
            return p.basePitch + p.animalCrossingPitchBoost
        }
    }

    /// Returns playback rate adjusted for the given emotion style.
    static func rate(for agentID: String?, emotion: SupertonicEmotionStyle?) -> Float {
        let p = CharacterVoiceProfileCatalog.profile(for: agentID)
        guard let emotion else { return p.baseRate }
        switch emotion {
        case .neutral:
            return p.baseRate
        case .careful:
            return p.baseRate + min(0, p.emotionRateBoost)
        case .friendly, .confident, .excited:
            return p.baseRate + p.emotionRateBoost
        case .animalCrossing:
            return p.baseRate + p.animalCrossingRateBoost
        }
    }

    /// Returns synthesis speed adjusted for the given emotion style.
    static func speed(for agentID: String?, emotion: SupertonicEmotionStyle?) -> Float {
        let p = CharacterVoiceProfileCatalog.profile(for: agentID)
        guard let emotion else { return p.baseSpeed }
        switch emotion {
        case .neutral:
            return p.baseSpeed
        case .careful:
            return p.baseSpeed + min(0, p.emotionSpeedBoost)
        case .friendly, .confident, .excited:
            return p.baseSpeed + p.emotionSpeedBoost
        case .animalCrossing:
            return p.baseSpeed + 0.12
        }
    }

    // MARK: - Style / Sample Info

    /// Returns the style note (display-only) for the given agentID.
    static func styleNote(for agentID: String?) -> String {
        CharacterVoiceProfileCatalog.profile(for: agentID).styleNote
    }

    /// Returns the sample line for the given agentID (TTS Lab preview).
    static func sampleLine(for agentID: String?) -> String {
        CharacterVoiceProfileCatalog.profile(for: agentID).sampleLine
    }
}
