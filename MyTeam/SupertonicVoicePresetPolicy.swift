import Foundation

// MARK: - SupertonicVoicePresetPolicy
// Round 258TTS-CHARACTER-VOICE-SYSTEM: CharacterVoiceProfileCatalog 기반으로 교체.
//
// Round 256TTS에서 agentID switch로 구현된 preset 매핑을 CharacterVoiceProfileCatalog에 위임.
// pitch/rate/speed/styleNote/sampleLine API 추가.
// unknown agentID → 루나(F1) 기본값 (CharacterVoiceProfileCatalog.profile 동작과 동일).

enum SupertonicVoicePresetPolicy {

    /// Returns the Supertonic3 voice preset for the given agentID.
    static func preset(for agentID: String?) -> String {
        CharacterVoiceProfileCatalog.profile(for: agentID).preset
    }

    /// Returns the pitch (cents, AVAudioUnitTimePitch) for the given agentID.
    static func pitch(for agentID: String?) -> Float {
        CharacterVoiceProfileCatalog.profile(for: agentID).basePitch
    }

    /// Returns the playback rate multiplier for the given agentID.
    static func rate(for agentID: String?) -> Float {
        CharacterVoiceProfileCatalog.profile(for: agentID).baseRate
    }

    /// Returns the Supertonic3 synthesis speed scale for the given agentID.
    static func speed(for agentID: String?) -> Float {
        CharacterVoiceProfileCatalog.profile(for: agentID).baseSpeed
    }

    /// Returns the style note (display-only) for the given agentID.
    static func styleNote(for agentID: String?) -> String {
        CharacterVoiceProfileCatalog.profile(for: agentID).styleNote
    }

    /// Returns the sample line for the given agentID (TTS Lab preview).
    static func sampleLine(for agentID: String?) -> String {
        CharacterVoiceProfileCatalog.profile(for: agentID).sampleLine
    }
}
