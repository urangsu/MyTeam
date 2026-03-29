import Foundation
import Combine

// AgentPersona, agentPersonas, AIServiceError → AgentPersona.swift 로 분리됨

// MARK: - AIService

class AIService: ObservableObject {
    static let shared = AIService()

    @Published var isProcessing = false

    private var providerIndex = 0
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Available Providers

    private var availableProviders: [String] {
        var providers: [String] = []
        if let key = UserDefaults.standard.string(forKey: "geminiAPIKey"), !key.isEmpty {
            providers.append("Gemini")
        }
        if let key = UserDefaults.standard.string(forKey: "openaiAPIKey"), !key.isEmpty {
            providers.append("OpenAI")
        }
        if let key = UserDefaults.standard.string(forKey: "claudeAPIKey"), !key.isEmpty {
            providers.append("Claude")
        }
        return providers
    }

    private func getNextProvider() -> String? {
        let providers = availableProviders
        guard !providers.isEmpty else { return nil }
        let provider = providers[providerIndex % providers.count]
        providerIndex = (providerIndex + 1) % providers.count
        return provider
    }

    // MARK: - Public API

    /// Send message and get AI response
    func getResponse(text: String, agentID: String, chatHistory: [String]) async throws -> (text: String, provider: String) {
        await MainActor.run { isProcessing = true }
        defer { Task { @MainActor in isProcessing = false } }

        guard let provider = getNextProvider() else {
            throw AIServiceError.noAPIKeys
        }

        let personaInfo = agentPersonas[agentID] ?? agentPersonas["agent_1"]!
        let customPersona = UserDefaults.standard.string(forKey: "custom_persona_\(agentID)") ?? ""
        let userTitle = UserDefaults.standard.string(forKey: "userTitle") ?? "사용자님"

        // Build base persona with optional custom addition
        var basePersona = personaInfo.persona
        if !customPersona.isEmpty {
            basePersona += "\n\n[사용자 추가 설정, 반드시 이 규칙을 따를 것!]: \(customPersona)"
        }

        // System prompt (exact match from Python backend)
        let systemPrompt = """
        당신은 사용자(\(userTitle))에게 실질적이고 정확한 도움을 줘야 하는 AI 어시스턴트입니다.
        사용자가 날씨, 지식, 정보 검색 등 범용적인 질문을 하면, 역할극(Roleplay)에 심취해 답변을 회피하지 말고 반드시 '진짜 대답(정보)'을 먼저 제공하세요.
        만일 사용자의 질문에 위치, 시간 등 명확한 답변을 위한 핵심 정보가 누락되어 있다면 절대 임의로 대답을 지어내거나 모른다고 방어적으로 말하지 마세요. 대신 "어느 지역의 날씨를 원하시나요?" 처럼 구체적인 정보를 되물어보세요.
        그 정보를 전달하는 '말투'와 '성격'만 아래의 페르소나를 따르시면 됩니다. 사용자(\(userTitle))를 부를 때는 반드시 '\(userTitle)'이라는 호칭을 사용하세요.

        [당신의 페르소나]
        \(basePersona)

        당장은 아주 짧고 임팩트 있게 한 문장이나 혹은 두 문장 내외로만 대답하세요.
        """

        // Build recent history (last 8 entries, same as Python backend)
        let recentHistory: [String]
        if chatHistory.count > 8 {
            recentHistory = Array(chatHistory.suffix(8))
        } else {
            recentHistory = chatHistory
        }
        let historyText = recentHistory.joined(separator: "\n")

        let fullPrompt = """
        [팀 대화 기록 (위에서부터 과거)]
        \(historyText)

        [현재 사용자의 요청 또는 동료의 말]
        \(text)

        위 대화 맥락과 제공된 페르소나에 맞게, 다른 팀원을 부를 땐 이름을 직접 언급하며 자연스럽게 대답해줘.
        """

        do {
            let responseText: String
            switch provider {
            case "Gemini":
                responseText = try await callGemini(systemPrompt: systemPrompt, userPrompt: fullPrompt)
            case "OpenAI":
                responseText = try await callOpenAI(systemPrompt: systemPrompt, userPrompt: fullPrompt)
            case "Claude":
                responseText = try await callClaude(systemPrompt: systemPrompt, userPrompt: fullPrompt)
            default:
                throw AIServiceError.invalidProvider(provider)
            }
            return (text: responseText.trimmingCharacters(in: .whitespacesAndNewlines), provider: provider)
        } catch let error as AIServiceError {
            throw error
        } catch {
            return (text: "[\(provider) 에러 발생]: \(error.localizedDescription)", provider: provider)
        }
    }

    /// Validate API key by making a minimal test request
    func validateKey(provider: String, apiKey: String) async throws -> String {
        switch provider {
        case "Gemini":
            return try await validateGeminiKey(apiKey: apiKey)
        case "OpenAI":
            return try await validateOpenAIKey(apiKey: apiKey)
        case "Claude":
            return try await validateClaudeKey(apiKey: apiKey)
        default:
            throw AIServiceError.invalidProvider(provider)
        }
    }

    // MARK: - Gemini API

    private func callGemini(systemPrompt: String, userPrompt: String) async throws -> String {
        guard let apiKey = UserDefaults.standard.string(forKey: "geminiAPIKey"), !apiKey.isEmpty else {
            throw AIServiceError.noAPIKeys
        }

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw AIServiceError.invalidResponse
        }

        // Gemini combines system + user into a single prompt
        let combinedPrompt = "\(systemPrompt)\n\n\(userPrompt)"

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": combinedPrompt]
                    ]
                ]
            ],
            "generationConfig": [
                "maxOutputTokens": 300
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let candidates = json?["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw AIServiceError.invalidResponse
        }

        return text
    }

    private func validateGeminiKey(apiKey: String) async throws -> String {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw AIServiceError.invalidResponse
        }

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": "hi"]]]
            ],
            "generationConfig": [
                "maxOutputTokens": 5
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)
        return "Gemini API 연동 성공!"
    }

    // MARK: - OpenAI API

    private func callOpenAI(systemPrompt: String, userPrompt: String) async throws -> String {
        guard let apiKey = UserDefaults.standard.string(forKey: "openaiAPIKey"), !apiKey.isEmpty else {
            throw AIServiceError.noAPIKeys
        }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw AIServiceError.invalidResponse
        }

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 300
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.invalidResponse
        }

        return content
    }

    private func validateOpenAIKey(apiKey: String) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw AIServiceError.invalidResponse
        }

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "user", "content": "hi"]
            ],
            "max_tokens": 2
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)
        return "OpenAI API 연동 성공!"
    }

    // MARK: - Claude API

    private func callClaude(systemPrompt: String, userPrompt: String) async throws -> String {
        guard let apiKey = UserDefaults.standard.string(forKey: "claudeAPIKey"), !apiKey.isEmpty else {
            throw AIServiceError.noAPIKeys
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AIServiceError.invalidResponse
        }

        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 300,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userPrompt]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let contentArray = json?["content"] as? [[String: Any]],
              let firstBlock = contentArray.first,
              let text = firstBlock["text"] as? String else {
            throw AIServiceError.invalidResponse
        }

        return text
    }

    private func validateClaudeKey(apiKey: String) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AIServiceError.invalidResponse
        }

        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 2,
            "messages": [
                ["role": "user", "content": "hi"]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)
        return "Claude API 연동 성공!"
    }

    // MARK: - HTTP Response Validation

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            // Try to extract a meaningful error message from JSON response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw AIServiceError.httpError(httpResponse.statusCode, message)
                }
            }
            throw AIServiceError.httpError(httpResponse.statusCode, errorBody)
        }
    }
}
