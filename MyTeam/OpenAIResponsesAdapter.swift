import Foundation
import CryptoKit

enum OpenAIResponsesAdapter {
    enum AdapterError: LocalizedError, Equatable {
        case unsupportedModel(String)
        case malformedResponse
        case emptyGeneration
        case incomplete(String)
        case providerFailure(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedModel(let modelID):
                return "\(modelID) 모델은 Responses 경로로 검증되지 않았습니다."
            case .malformedResponse:
                return "OpenAI 응답 형식을 확인하지 못했습니다."
            case .emptyGeneration:
                return "OpenAI가 비어 있는 응답을 반환했습니다."
            case .incomplete(let reason):
                return "OpenAI 응답이 완료되지 않았습니다: \(reason)"
            case .providerFailure(let message):
                return "OpenAI 응답 실패: \(message)"
            }
        }
    }

    enum StreamEvent: Equatable {
        case text(String)
        case completed
        case incomplete(String)
        case failed(String)
        case ignored
    }

    private static let endpoint = URL(string: "https://api.openai.com/v1/responses")!
    private static let safetyIdentifierDefaultsKey = "MyTeam.OpenAI.SafetyIdentifier.v1"

    static func supports(modelID: String) -> Bool {
        let value = modelID.lowercased()
        let pattern = #"^gpt-5\.6(?:-(?:sol|terra|luna)(?:-\d{4}-\d{2}-\d{2})?|-\d{4}-\d{2}-\d{2})?$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    static func makeRequest(
        apiKey: String,
        modelID: String,
        messages: [[String: Any]],
        instructions: String?,
        maxOutputTokens: Int,
        stream: Bool,
        reasoningEffort: String = "low",
        safetyIdentifier: String = installationSafetyIdentifier()
    ) throws -> URLRequest {
        guard supports(modelID: modelID) else {
            throw AdapterError.unsupportedModel(modelID)
        }

        var body: [String: Any] = [
            "model": modelID,
            "input": messages,
            "stream": stream,
            "store": false,
            "max_output_tokens": maxOutputTokens,
            "reasoning": ["effort": reasoningEffort],
            "safety_identifier": safetyIdentifier
        ]
        if let instructions, !instructions.isEmpty {
            body["instructions"] = instructions
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func parseEvent(_ dataString: String) throws -> StreamEvent {
        guard let data = dataString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            throw AdapterError.malformedResponse
        }

        switch type {
        case "response.output_text.delta":
            guard let delta = json["delta"] as? String else {
                throw AdapterError.malformedResponse
            }
            return delta.isEmpty ? .ignored : .text(delta)
        case "response.completed":
            return .completed
        case "response.incomplete":
            let response = json["response"] as? [String: Any]
            let details = response?["incomplete_details"] as? [String: Any]
            return .incomplete(details?["reason"] as? String ?? "unknown")
        case "response.failed":
            let response = json["response"] as? [String: Any]
            let error = response?["error"] as? [String: Any]
            return .failed(sanitizedMessage(error?["message"] as? String) ?? "provider failure")
        case "error":
            let error = json["error"] as? [String: Any]
            let message = (json["message"] as? String) ?? (error?["message"] as? String)
            return .failed(sanitizedMessage(message) ?? "provider failure")
        default:
            return .ignored
        }
    }

    static func outputText(from data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AdapterError.malformedResponse
        }
        if let status = json["status"] as? String, status == "incomplete" {
            let details = json["incomplete_details"] as? [String: Any]
            throw AdapterError.incomplete(details?["reason"] as? String ?? "unknown")
        }
        if let error = json["error"] as? [String: Any],
           let message = sanitizedMessage(error["message"] as? String) {
            throw AdapterError.providerFailure(message)
        }

        let output = json["output"] as? [[String: Any]] ?? []
        let text = output.flatMap { item -> [String] in
            let content = item["content"] as? [[String: Any]] ?? []
            return content.compactMap { part in
                guard part["type"] as? String == "output_text" else { return nil }
                return part["text"] as? String
            }
        }.joined()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AdapterError.emptyGeneration }
        return trimmed
    }

    static func providerErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let error = json["error"] as? [String: Any]
        return sanitizedMessage(error?["message"] as? String ?? json["message"] as? String)
    }

    static func installationSafetyIdentifier() -> String {
        if let existing = UserDefaults.standard.string(forKey: safetyIdentifierDefaultsKey),
           existing.hasPrefix("myteam_") {
            return existing
        }
        let random = UUID().uuidString
        let digest = SHA256.hash(data: Data(random.utf8))
        let identifier = "myteam_" + digest.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(identifier, forKey: safetyIdentifierDefaultsKey)
        return identifier
    }

    private static func sanitizedMessage(_ message: String?) -> String? {
        guard let message else { return nil }
        let compact = message
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !compact.isEmpty else { return nil }
        return String(compact.prefix(300))
    }
}
