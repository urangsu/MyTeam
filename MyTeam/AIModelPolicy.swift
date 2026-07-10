import Foundation

// MARK: - AIModelPolicy
// Round 269A-MODEL-TRUTH-GATE: LLMModelRegistry wrapper.
// 모든 모델 ID는 LLMModelRegistry에서 가져온다.
// 직접 모델 문자열을 여기서 정의하지 않는다.

enum AIModelPolicy {
    /// DEBUG에서만 수동 모델 오버라이드 허용 (UserDefaults 설정 경로)
    static var modelOverrideAllowed: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Dynamic discovery is diagnostic-only until discovered models pass a real generation smoke.
    /// Release uses explicitly reviewed registry IDs so a higher-version preview or incompatible
    /// endpoint model cannot become the production default merely by appearing in /models.
    static var dynamicModelDiscoveryAllowed: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// DEBUG: UserDefaults 오버라이드 허용. Release: registry primary 사용.
    static var defaultModel: String {
        #if DEBUG
        let override = UserDefaults.standard.string(forKey: "MyTeam.DebugModelOverride") ?? ""
        return override.isEmpty ? LLMModelRegistry.OpenAI.primary : override
        #else
        return LLMModelRegistry.OpenAI.primary
        #endif
    }

    /// provider별 floor fallback model ID.
    /// discovery 실패 시 최후 안전망으로 사용.
    static func pinnedModelID(for provider: LLMProvider) -> String {
        switch provider {
        case .gemini:
            return LLMModelRegistry.Gemini.primary
        case .openAI:
            return LLMModelRegistry.OpenAI.resolve(configured: modelOverrideAllowed
                ? UserDefaults.standard.string(forKey: "MyTeam.DebugModelOverride")
                : nil)
        case .claude:
            return LLMModelRegistry.Claude.primary
        case .openRouter:
            return LLMModelRegistry.OpenRouter.primary
        }
    }

    /// 사용자 설정값이 있으면 사용하되 알려진 불량 모델은 pinned으로 대체.
    static func resolvedModelID(provider: LLMProvider, configuredModelID: String?) -> String {
        guard modelOverrideAllowed else {
            return pinnedModelID(for: provider)
        }
        let trimmed = configuredModelID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty || LLMModelRegistry.isKnownBroken(trimmed) {
            return pinnedModelID(for: provider)
        }
        return trimmed
    }

    static var modelFamily: String {
        LLMModelRegistry.defaultModelFamilyLabel
    }
}
