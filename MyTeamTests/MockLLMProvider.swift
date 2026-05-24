import Foundation
@testable import MyTeam

// MARK: - MockLLMProvider
// Round 270C: Fake provider for behavioral LLM routing tests.
// Provides controlled responses without real network calls.

struct MockLLMResponse {
    let text: String
    let modelID: String
    let providerName: String
    var shouldFail: Bool = false
    var failureReason: String = "mock fail"
}

/// Minimal mock that records call log without hitting real APIs.
/// Used in LLMRouterTests for routing + fallback verification.
final class MockAIProvider {
    var responses: [LLMProvider: MockLLMResponse] = [:]
    var callLog: [(provider: LLMProvider, model: String, requiresToolUse: Bool)] = []

    func getResponse(
        provider: LLMProvider,
        requiresToolUse: Bool
    ) throws -> (text: String, provider: String) {
        callLog.append((provider, responses[provider]?.modelID ?? "", requiresToolUse))
        guard let resp = responses[provider], !resp.shouldFail else {
            throw MockError.providerFailed(responses[provider]?.failureReason ?? "mock fail")
        }
        return (resp.text, resp.providerName)
    }

    enum MockError: Error {
        case providerFailed(String)
    }
}
