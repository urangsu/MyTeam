import Foundation

enum BYOKPolicy {
    static let isBYOKSupported = true
    static let byokDoesNotConsumeIncludedCredits = true
    static let includedCreditsAreOnboardingOnly = true

    static let supportedProviders: [LLMProvider] = [
        .openAI,
        .claude,
        .gemini,
        .openRouter
    ]
}
