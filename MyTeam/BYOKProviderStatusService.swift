import Foundation

enum BYOKProviderStatusService {
    static func loadStatuses() -> [BYOKProviderStatus] {
        [
            makeStatus(displayName: "OpenAI", providerKey: LLMProvider.openAI.rawValue, provider: .openAI),
            makeStatus(displayName: "Claude", providerKey: LLMProvider.claude.rawValue, provider: .anthropic),
            makeStatus(displayName: "Gemini", providerKey: LLMProvider.gemini.rawValue, provider: .gemini),
            makeStatus(displayName: "OpenRouter", providerKey: LLMProvider.openRouter.rawValue, provider: .openRouter)
        ]
    }

    private static func makeStatus(displayName: String, providerKey: String, provider: ExternalProvider) -> BYOKProviderStatus {
        let isConnected = SecureCredentialStore.shared.hasKey(for: provider)
        return BYOKProviderStatus(
            id: providerKey,
            displayName: displayName,
            providerKey: providerKey,
            isConnected: isConnected,
            storageLabel: "이 Mac",
            helpText: isConnected ? "개인 API 키가 저장되어 있습니다. 실제 연결 여부는 연결 테스트로 확인하세요." : "설정 탭에서 API 키를 입력하세요."
        )
    }
}
