import Foundation

enum BYOKProviderStatusService {
    static func loadStatuses() -> [BYOKProviderStatus] {
        [
            makeStatus(displayName: "OpenAI", providerKey: LLMProvider.openAI.rawValue, keychainKey: "openAIAPIKey"),
            makeStatus(displayName: "Claude", providerKey: LLMProvider.claude.rawValue, keychainKey: "claudeAPIKey"),
            makeStatus(displayName: "Gemini", providerKey: LLMProvider.gemini.rawValue, keychainKey: "geminiAPIKey"),
            makeStatus(displayName: "OpenRouter", providerKey: LLMProvider.openRouter.rawValue, keychainKey: "openRouterAPIKey")
        ]
    }

    private static func makeStatus(displayName: String, providerKey: String, keychainKey: String) -> BYOKProviderStatus {
        let isConnected = !(KeychainManager.load(key: keychainKey) ?? "").isEmpty
        return BYOKProviderStatus(
            id: providerKey,
            displayName: displayName,
            providerKey: providerKey,
            isConnected: isConnected,
            storageLabel: "Keychain",
            helpText: isConnected ? "개인 API 키가 연결되어 있습니다." : "설정 탭에서 API 키를 입력하세요."
        )
    }
}
