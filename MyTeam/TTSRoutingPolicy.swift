import Foundation

// MARK: - TTSRoutingPolicy
// Round 251TTS: Supertonic3 단독 후보.
//
// 정책:
// - Apple TTS (AVSpeechSynthesizer): 영원히 금지. 폴백 포함.
// - Supertonic3: isEnabled && modelAvailable 일 때만 선택.
// - 해당 없음 → nil → 무음. 폴백 없음.

enum TTSRoutingPolicy {

    // MARK: - Provider Selection

    /// 현재 활성화할 TTS provider 반환.
    /// nil = 무음 (provider 없음).
    /// ⚠️ Apple TTS (AVSpeechSynthesizer)는 절대 반환하지 않는다.
    static func selectedProvider() -> TTSProviderKind? {
        if Supertonic3TTSConfig.isEnabled && Supertonic3ModelLocator.isModelAvailable() {
            return .supertonic3
        }
        // 무음. Apple TTS / 기타 폴백 없음.
        return nil
    }

    // MARK: - Availability Summary

    static func availabilitySummary() -> [TTSProviderKind: TTSProviderAvailability] {
        var result: [TTSProviderKind: TTSProviderAvailability] = [:]
        if !Supertonic3TTSConfig.isEnabled {
            result[.supertonic3] = .experimental
        } else if !Supertonic3ModelLocator.isModelAvailable() {
            result[.supertonic3] = .missingModel
        } else {
            result[.supertonic3] = .runtimeUnavailable
        }
        return result
    }

    // MARK: - Policy Guards

    /// Apple TTS 금지 정책 선언 (정적 마커).
    static func appleSystemTTSIsPermanentlyForbidden() -> Bool { true }
}
