import Foundation

// MARK: - SupertonicVoicePresetPolicy
// Round 258B: emotion-aware pitch/rate/speed API.
// Round 259TTS: animalCrossingTuning(for:) 추가 — AC는 별도 target으로 분리.
//
// base API: pitch/rate/speed(for:) — 기본값 반환 (emotion nil 위임).
// emotion-aware API: pitch/rate/speed(for:emotion:) — emotion에 따라 boost 적용.
//   - neutral: base 값 그대로
//   - careful: base + min(0, boost) — 음수 boost만 적용 (더 조심스럽게)
//   - friendly, confident, excited: base + boost 전체 적용
//   - animalCrossing: animalCrossingTuning(for:) 별도 target (기존 boost 누적 방식 제거)
// emotionStyle(for:): 캐릭터 기본 감정 반환 (SpeechManager에서 사용)
// animalCrossingTuning(for:): AC 별도 cartoon target (M preset→+140, F preset→+180)

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
            // Round 259: 별도 cartoon target — boost 누적 방식 제거
            return animalCrossingTuning(for: agentID).pitch
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
            return animalCrossingTuning(for: agentID).rate
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
            return animalCrossingTuning(for: agentID).speed
        }
    }

    // MARK: - Animal Crossing Separate Tuning (Round 259TTS)

    /// Animal Crossing 별도 tuning target.
    /// 기존 base + boost 누적 방식이 아닌, 독립적인 cartoon 목표값으로 이동.
    /// M preset: targetPitch +140, F preset: targetPitch +180, rate 1.12
    /// 테스트 전용 모드 — 기본 캐릭터 발화에는 사용되지 않음.
    static func animalCrossingTuning(for agentID: String?) -> VoiceTuningValues {
        let p = CharacterVoiceProfileCatalog.profile(for: agentID)
        let targetPitch: Float
        switch p.preset.first {
        case "M": targetPitch = 140
        case "F": targetPitch = 180
        default:  targetPitch = 160
        }
        return VoiceTuningValues(
            pitch: targetPitch,
            rate:  1.12,
            speed: min(1.20, p.baseSpeed + 0.12)
        )
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
