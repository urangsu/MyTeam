import Foundation

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

    static var defaultModel: String {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "MyTeam.DebugModelOverride") ?? "gpt-5.5"
        #else
        return "gpt-5.5"
        #endif
    }

    static func pinnedModelID(for provider: LLMProvider) -> String {
        switch provider {
        case .gemini:
            return "gemini-2.0-flash"
        case .openAI:
            return defaultModel
        case .claude:
            return "claude-opus-4-7"
        case .openRouter:
            return "openai/gpt-5.5"
        }
    }

    static func resolvedModelID(provider: LLMProvider, configuredModelID: String?) -> String {
        guard modelOverrideAllowed else {
            return pinnedModelID(for: provider)
        }

        let trimmed = configuredModelID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? pinnedModelID(for: provider) : trimmed
    }

    static var modelFamily: String {
        "gpt-5"
    }
}
