import Foundation

// MARK: - TTSRoutingPolicy
// Round 256TTS-OFFICIAL-ENGINE: Supertonic3 공식 TTS 엔진 라우팅.
//
// 정책:
// - Apple TTS (AVSpeechSynthesizer): 영원히 금지. 폴백 포함.
// - Supertonic3: officialEngineEnabled + enabled + notice accepted + model available + runtime linked
// - 해당 없음 → nil → 무음. 폴백 없음.
// - auto-speak 기본 OFF (TTSProductPolicy.autoSpeakDefaultEnabled = false).

enum TTSRoutingPolicy {

    // MARK: - Provider Selection

    /// 현재 활성화할 TTS provider 반환.
    /// nil = 무음 (provider 없음 또는 조건 미충족).
    /// ⚠️ Apple TTS (AVSpeechSynthesizer)는 절대 반환하지 않는다.
    static func selectedProvider() -> TTSProviderKind? {
        guard TTSProductPolicy.officialEngineEnabled else { return nil }
        guard Supertonic3TTSConfig.isEnabled else { return nil }
        guard SupertonicTTSNoticePolicy.isCurrentNoticeAccepted else { return nil }
        guard Supertonic3ModelLocator.isModelAvailable() else { return nil }
        guard Supertonic3ONNXRuntimeProbe.isRuntimeLinked else { return nil }
        return .supertonic3
    }

    /// Returns true if selectedProvider() can currently return .supertonic3.
    static var isSupertonic3Available: Bool {
        selectedProvider() == .supertonic3
    }

    // MARK: - Availability Summary

    static func availabilitySummary() -> [TTSProviderKind: TTSProviderAvailability] {
        var result: [TTSProviderKind: TTSProviderAvailability] = [:]
        if !Supertonic3TTSConfig.isEnabled {
            result[.supertonic3] = .experimental
        } else if !Supertonic3ModelLocator.isModelAvailable() {
            result[.supertonic3] = .missingModel
        } else if !Supertonic3ONNXRuntimeProbe.isRuntimeLinked {
            result[.supertonic3] = .runtimeUnavailable
        } else if !SupertonicTTSNoticePolicy.isCurrentNoticeAccepted {
            result[.supertonic3] = .noticeRequired
        } else {
            result[.supertonic3] = .runtimeReady
        }
        return result
    }

    // MARK: - Policy Guards

    /// Apple TTS 금지 정책 선언 (정적 마커).
    static func appleSystemTTSIsPermanentlyForbidden() -> Bool { true }

    /// auto-speak 기본값 정책. 항상 false — 사용자가 명시적으로 켜야 함.
    static var autoSpeakDefault: Bool { TTSProductPolicy.autoSpeakDefaultEnabled }
}
