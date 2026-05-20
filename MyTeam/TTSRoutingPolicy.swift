import Foundation

// MARK: - TTSRoutingPolicy
// Round 247TTS-SUPERTONIC3-POC: TTS provider 선택 정책.
//
// 정책:
// - Apple TTS (AVSpeechSynthesizer): 이 파일 어디에도 없음. 프로젝트 정책: 영원히 금지.
// - Supertonic3: isEnabled && modelAvailable 일 때 선택 (현재 Cloud: model 없으면 항상 false)
// - Qwen3: Developer Lab ttsDevLabQwen3Override + enableExperimentalQwenTTS 두 플래그 동시에 켜져야 활성
// - 아무것도 해당 없음 → nil 반환 → SpeechManager에서 무음 처리
// - 무음은 허용됨. Apple TTS 폴백은 절대 허용 안 됨.

enum TTSRoutingPolicy {

    // MARK: - Provider Selection

    /// 현재 활성화할 TTS provider를 반환.
    /// nil = 무음 (no provider active).
    /// ⚠️ Apple TTS (AVSpeechSynthesizer)는 절대 반환하지 않는다 — 프로젝트 정책.
    static func selectedProvider() -> TTSProviderKind? {
        // 1순위: Supertonic3 (실험용, 로컬 모델 필요)
        if Supertonic3TTSConfig.isEnabled && Supertonic3ModelLocator.isModelAvailable() {
            return .supertonic3
        }

        // 2순위: Qwen3 (Developer Lab override 전용)
        // ttsDevLabQwen3Override 없이는 enableExperimentalQwenTTS만으로 활성화 불가
        if UserDefaults.standard.bool(forKey: "ttsDevLabQwen3Override")
            && UserDefaults.standard.bool(forKey: "enableExperimentalQwenTTS") {
            return .qwen3MLX
        }

        // 3순위: 없음 → 무음
        // Apple TTS (AVSpeechSynthesizer)는 여기서 절대 반환하지 않는다.
        return nil
    }

    // MARK: - Availability Summary

    /// 각 provider의 현재 활성화 가능 여부 요약 (진단/Lab UI용)
    static func availabilitySummary() -> [TTSProviderKind: TTSProviderAvailability] {
        var result: [TTSProviderKind: TTSProviderAvailability] = [:]

        // Supertonic3
        if !Supertonic3TTSConfig.isEnabled {
            result[.supertonic3] = .experimental
        } else if !Supertonic3ModelLocator.isModelAvailable() {
            result[.supertonic3] = .missingModel
        } else {
            // isEnabled && modelAvailable → runtimeUnavailable (Cloud), available (Mac 248TTS 이후)
            result[.supertonic3] = .runtimeUnavailable
        }

        // Qwen3
        let qwen3DevLabActive = UserDefaults.standard.bool(forKey: "ttsDevLabQwen3Override")
        result[.qwen3MLX] = qwen3DevLabActive ? .available : .disabledByPolicy

        return result
    }

    // MARK: - Policy Guards

    /// Apple TTS 금지 정책 선언 (코드 검색을 위한 정적 마커)
    /// ToolContractValidator에서 AVSpeechSynthesizer 없음 검사에 대응.
    /// 이 함수는 실제로 호출할 필요 없음 — 정책 가시화용.
    static func appleSystemTTSIsPermanentlyForbidden() -> Bool {
        // 반드시 true. Apple TTS는 이 앱에서 영원히 금지.
        // 폴백 포함 어떤 형태로도 AVSpeechSynthesizer 사용 금지.
        return true
    }
}
