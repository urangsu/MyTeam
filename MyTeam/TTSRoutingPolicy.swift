import Foundation

// MARK: - TTSRoutingPolicy
// Supertonic3 ONNX pipeline 제거 후 — TTS provider 없음.
// Apple TTS (AVSpeechSynthesizer): 영원히 금지. 폴백 포함.
// auto-speak 기본 OFF (TTSProductPolicy.autoSpeakDefaultEnabled = false).

enum TTSRoutingPolicy {

    // MARK: - Provider Selection

    /// 현재 활성화할 TTS provider 반환.
    /// nil = 무음 (provider 없음 — ONNX pipeline 제거됨).
    /// ⚠️ Apple TTS (AVSpeechSynthesizer)는 절대 반환하지 않는다.
    static func selectedProvider() -> TTSProviderKind? {
        return nil   // Supertonic3 ONNX pipeline removed
    }

    /// Returns true if selectedProvider() can currently return .supertonic3.
    static var isSupertonic3Available: Bool { false }

    // MARK: - Availability Summary

    static func availabilitySummary() -> [TTSProviderKind: TTSProviderAvailability] {
        return [.supertonic3: .experimental]
    }

    // MARK: - Policy Guards

    /// Apple TTS 금지 정책 선언 (정적 마커).
    static func appleSystemTTSIsPermanentlyForbidden() -> Bool { true }

    /// auto-speak 기본값 정책. 항상 false — 사용자가 명시적으로 켜야 함.
    static var autoSpeakDefault: Bool { TTSProductPolicy.autoSpeakDefaultEnabled }
}
