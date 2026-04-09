import Foundation
import Combine


// MARK: - AIService (ModelRouter 통합)
final class AIService {
    static let shared = AIService()
    private init() {}

    @MainActor @Published var isProcessing: Bool = false
    private let session = URLSession.shared

    // MARK: - ModelRouter: SSE 스트림 (에이전트별 LLM 동적 라우팅)
    /// agentConfig.llmProvider에 따라 Gemini / Claude / OpenRouter로 라우팅
    /// openRouter 사용 시 agentConfig.openRouterModelId가 동적으로 삽입됨
    func getResponseStream(
        text: String,
        agentID: String,
        chatHistory: [AgentWindowManager.ChatLog],
        agentConfig: AgentWindowManager.AgentConfig? = nil
    ) -> AsyncThrowingStream<String, Error> {

        let provider = agentConfig?.llmProvider ?? .gemini

        switch provider {
        case .gemini:
            return geminiStream(text: text, agentID: agentID, chatHistory: chatHistory)
        case .openAI:
            let modelId = UserDefaults.standard.string(forKey: "openAIModelId") ?? "gpt-4o"
            return openAIStream(text: text, agentID: agentID, chatHistory: chatHistory, modelId: modelId)
        case .claude:
            return claudeStream(text: text, agentID: agentID, chatHistory: chatHistory)
        case .openRouter:
            let modelId = agentConfig?.openRouterModelId ?? "meta-llama/llama-3-8b-instruct"
            return openRouterStream(text: text, agentID: agentID, chatHistory: chatHistory, modelId: modelId)
        }
    }

    // MARK: - Gemini SSE Stream
    private func geminiStream(
        text: String,
        agentID: String,
        chatHistory: [AgentWindowManager.ChatLog]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await MainActor.run { isProcessing = true }
                defer { Task { @MainActor in isProcessing = false } }

                let apiKey = KeychainManager.load(key: "geminiAPIKey") ?? ""
                guard !apiKey.isEmpty else {
                    continuation.finish(throwing: AIServiceError.noAPIKeys)
                    return
                }

                let model = "gemini-2.0-flash"
                guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?key=\(apiKey)&alt=sse") else {
                    continuation.finish(throwing: AIServiceError.invalidResponse)
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let messages = buildGeminiMessages(text: text, chatHistory: chatHistory)
                let body: [String: Any] = ["contents": messages]
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)

                do {
                    let (result, response) = try await session.bytes(for: request)
                    guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                        continuation.finish(throwing: AIServiceError.invalidResponse)
                        return
                    }

                    print("[AIService] ⚡ Gemini SSE 채널 오픈 (agent: \(agentID))")
                    for try await line in result.lines {
                        if Task.isCancelled { break }
                        if line.hasPrefix("data: ") {
                            let dataStr = String(line.dropFirst(6))
                            if dataStr == "[DONE]" { break }
                            if let token = parseGeminiToken(dataStr) {
                                continuation.yield(token)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Claude SSE Stream
    private func claudeStream(
        text: String,
        agentID: String,
        chatHistory: [AgentWindowManager.ChatLog]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await MainActor.run { isProcessing = true }
                defer { Task { @MainActor in isProcessing = false } }

                let apiKey = KeychainManager.load(key: "claudeAPIKey") ?? ""
                guard !apiKey.isEmpty else {
                    continuation.finish(throwing: AIServiceError.noAPIKeys)
                    return
                }

                guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
                    continuation.finish(throwing: AIServiceError.invalidResponse)
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "content-type")
                request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

                let messages = buildAnthropicMessages(text: text, chatHistory: chatHistory)
                let body: [String: Any] = [
                    "model": "claude-3-5-sonnet-20240620",
                    "max_tokens": 1024,
                    "stream": true,
                    "messages": messages
                ]
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)

                do {
                    let (result, response) = try await session.bytes(for: request)
                    guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                        continuation.finish(throwing: AIServiceError.invalidResponse)
                        return
                    }

                    print("[AIService] ⚡ Claude SSE 채널 오픈 (agent: \(agentID))")
                    for try await line in result.lines {
                        if Task.isCancelled { break }
                        if line.hasPrefix("data: ") {
                            let dataStr = String(line.dropFirst(6))
                            if dataStr == "[DONE]" { break }
                            if let token = parseAnthropicToken(dataStr) {
                                continuation.yield(token)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - OpenAI SSE Stream (동적 모델명 주입)
    private func openAIStream(
        text: String,
        agentID: String,
        chatHistory: [AgentWindowManager.ChatLog],
        modelId: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await MainActor.run { isProcessing = true }
                defer { Task { @MainActor in isProcessing = false } }

                let apiKey = KeychainManager.load(key: "openAIAPIKey") ?? ""
                guard !apiKey.isEmpty else {
                    continuation.finish(throwing: AIServiceError.noAPIKeys)
                    return
                }

                guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
                    continuation.finish(throwing: AIServiceError.invalidResponse)
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

                let messages = buildOpenAIMessages(text: text, chatHistory: chatHistory)
                // modelId 동적 주입: SettingsView의 openAIModelId 필드 값이 그대로 body에 삽입됨
                let body: [String: Any] = [
                    "model": modelId,
                    "messages": messages,
                    "stream": true,
                    "max_tokens": 1024
                ]
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)

                do {
                    let (result, response) = try await session.bytes(for: request)
                    guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                        continuation.finish(throwing: AIServiceError.invalidResponse)
                        return
                    }

                    print("[AIService] ⚡ OpenAI SSE 채널 오픈 (model: \(modelId), agent: \(agentID))")
                    for try await line in result.lines {
                        if Task.isCancelled { break }
                        if line.hasPrefix("data: ") {
                            let dataStr = String(line.dropFirst(6))
                            if dataStr == "[DONE]" { break }
                            if let token = parseOpenAIToken(dataStr) {
                                continuation.yield(token)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - OpenRouter SSE Stream (동적 modelId 주입)
    private func openRouterStream(
        text: String,
        agentID: String,
        chatHistory: [AgentWindowManager.ChatLog],
        modelId: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await MainActor.run { isProcessing = true }
                defer { Task { @MainActor in isProcessing = false } }

                let apiKey = KeychainManager.load(key: "openRouterAPIKey") ?? ""
                guard !apiKey.isEmpty else {
                    continuation.finish(throwing: AIServiceError.noAPIKeys)
                    return
                }

                guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
                    continuation.finish(throwing: AIServiceError.invalidResponse)
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.setValue("MyTeam App", forHTTPHeaderField: "X-Title")

                let messages = buildOpenAIMessages(text: text, chatHistory: chatHistory)
                // modelId 동적 삽입: agentConfig.openRouterModelId 값이 그대로 body에 주입됨
                let body: [String: Any] = [
                    "model": modelId,
                    "messages": messages,
                    "stream": true
                ]
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)

                do {
                    let (result, response) = try await session.bytes(for: request)
                    guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                        continuation.finish(throwing: AIServiceError.invalidResponse)
                        return
                    }

                    print("[AIService] ⚡ OpenRouter SSE 채널 오픈 (model: \(modelId), agent: \(agentID))")
                    for try await line in result.lines {
                        if Task.isCancelled { break }
                        if line.hasPrefix("data: ") {
                            let dataStr = String(line.dropFirst(6))
                            if dataStr == "[DONE]" { break }
                            if let token = parseOpenAIToken(dataStr) {
                                continuation.yield(token)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Convenience: Non-Streaming (Stream 수집)
    func getResponse(
        text: String,
        agentID: String,
        chatHistory: [AgentWindowManager.ChatLog],
        agentConfig: AgentWindowManager.AgentConfig? = nil
    ) async throws -> (text: String, provider: String) {
        var fullText = ""
        let stream = getResponseStream(text: text, agentID: agentID, chatHistory: chatHistory, agentConfig: agentConfig)
        for try await token in stream { fullText += token }
        return (text: fullText, provider: agentConfig?.llmProvider.displayName ?? "Gemini")
    }

    // MARK: - Message Builders
    private func buildGeminiMessages(text: String, chatHistory: [AgentWindowManager.ChatLog]) -> [[String: Any]] {
        var contents: [[String: Any]] = []
        let recent = chatHistory.suffix(20)
        for log in recent {
            let role = log.isUser ? "user" : "model"
            contents.append(["role": role, "parts": [["text": log.text]]])
        }
        contents.append(["role": "user", "parts": [["text": text]]])
        return contents
    }

    private func buildAnthropicMessages(text: String, chatHistory: [AgentWindowManager.ChatLog]) -> [[String: Any]] {
        var messages: [[String: Any]] = []
        let recent = chatHistory.suffix(20)
        for log in recent {
            let role = log.isUser ? "user" : "assistant"
            messages.append(["role": role, "content": log.text])
        }
        messages.append(["role": "user", "content": text])
        return messages
    }

    private func buildOpenAIMessages(text: String, chatHistory: [AgentWindowManager.ChatLog]) -> [[String: Any]] {
        var messages: [[String: Any]] = []
        let recent = chatHistory.suffix(20)
        for log in recent {
            let role = log.isUser ? "user" : "assistant"
            messages.append(["role": role, "content": log.text])
        }
        messages.append(["role": "user", "content": text])
        return messages
    }

    // MARK: - Token Parsers
    private func parseGeminiToken(_ dataStr: String) -> String? {
        guard let data = dataStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else { return nil }
        return text
    }

    private func parseAnthropicToken(_ dataStr: String) -> String? {
        guard let data = dataStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["type"] as? String == "content_block_delta",
              let delta = json["delta"] as? [String: Any],
              let text = delta["text"] as? String else { return nil }
        return text
    }

    private func parseOpenAIToken(_ dataStr: String) -> String? {
        guard let data = dataStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let text = delta["content"] as? String else { return nil }
        return text
    }

    // MARK: - Key Validation
    func validateKey(provider: String, apiKey: String) async throws -> String {
        try await Task.sleep(nanoseconds: 500_000_000)
        guard apiKey.count >= 10 else {
            throw NSError(domain: "AIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "키가 너무 짧습니다."])
        }
        return "인증 성공"
    }
}
