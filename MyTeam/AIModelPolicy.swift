import Foundation

// MARK: - AIModelPolicy
// Round 264-MODEL-REGISTRY: LLMModelRegistry wrapper.
// 모든 모델 ID는 LLMModelRegistry에서 가져온다.
// 직접 모델 문자열을 여기서 정의하지 않는다.

enum AIModelPolicy {
    static var modelOverrideAllowed: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

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

    /// provider별 production pinned model ID.
    /// LLMModelRegistry에서 가져온다.
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

    /// 사용자 설정값이 있으면 사용하되 금지 목록 ID는 pinned으로 대체.
    static func resolvedModelID(provider: LLMProvider, configuredModelID: String?) -> String {
        guard modelOverrideAllowed else {
            return pinnedModelID(for: provider)
        }
        let trimmed = configuredModelID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty || LLMModelRegistry.isBlocked(trimmed) {
            return pinnedModelID(for: provider)
        }
        return trimmed
    }

    static var modelFamily: String {
        LLMModelRegistry.defaultModelFamilyLabel
    }
}
