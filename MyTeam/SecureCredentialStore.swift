import Foundation

// MARK: - SecureCredentialStore

/// API 키를 macOS Keychain에 안전하게 저장/조회/삭제합니다.
/// 내부적으로 KeychainManager를 사용하며, provider 추상화 레이어를 제공합니다.
///
/// - 절대 UserDefaults / plain text / 로그에 키를 저장하지 않습니다.
/// - Git에 키가 포함되지 않습니다.
/// - UI에서는 마스킹된 형태로만 표시합니다.
final class SecureCredentialStore {
    static let shared = SecureCredentialStore()
    private init() {}

    // MARK: - Save

    /// 지정 provider의 API 키를 Keychain에 저장합니다.
    /// - Returns: 저장 성공 여부
    @discardableResult
    func save(provider: ExternalProvider, key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return KeychainManager.save(key: provider.keychainKey, value: trimmed)
    }

    @discardableResult
    func save(provider: ExternalProvider, field: CredentialField, value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return KeychainManager.save(key: keychainKey(provider: provider, field: field), value: trimmed)
    }

    // MARK: - Read

    /// 지정 provider의 API 키를 Keychain에서 읽습니다.
    /// - Returns: 저장된 키, 없으면 nil
    func read(provider: ExternalProvider) -> String? {
        KeychainManager.load(key: provider.keychainKey)
    }

    func read(provider: ExternalProvider, field: CredentialField) -> String? {
        if let value = KeychainManager.load(key: keychainKey(provider: provider, field: field)) {
            return value
        }
        guard provider.credentialSchema.fields.count == 1 else {
            return nil
        }
        return KeychainManager.load(key: provider.keychainKey)
    }

    /// 키가 존재하는지 여부
    func hasKey(for provider: ExternalProvider) -> Bool {
        if provider.credentialSchema.fields.count > 1 {
            return hasAllRequiredFields(for: provider)
        }
        guard let key = read(provider: provider) else { return false }
        return !key.isEmpty
    }

    func hasAllRequiredFields(for provider: ExternalProvider) -> Bool {
        provider.credentialSchema.fields.allSatisfy { field in
            guard let value = read(provider: provider, field: field) else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func hasAnyAIProviderKey() -> Bool {
        [.gemini, .openAI, .anthropic, .openRouter].contains { provider in
            hasKey(for: provider)
        }
    }

    // MARK: - Delete

    /// 지정 provider의 API 키를 Keychain에서 삭제합니다.
    @discardableResult
    func delete(provider: ExternalProvider) -> Bool {
        KeychainManager.delete(key: provider.keychainKey)
    }

    @discardableResult
    func delete(provider: ExternalProvider, field: CredentialField) -> Bool {
        KeychainManager.delete(key: keychainKey(provider: provider, field: field))
    }

    // MARK: - Mask

    /// UI 표시용 마스킹 문자열. 마지막 4자만 보이고 나머지는 •로 가립니다.
    /// 예: "sk-abc...XYZ1" → "••••••••••XYZ1"
    func masked(provider: ExternalProvider) -> String {
        if provider.credentialSchema.fields.count > 1 {
            let filled = provider.credentialSchema.fields.filter { field in
                guard let value = read(provider: provider, field: field) else { return false }
                return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return filled.isEmpty ? "미연결" : "\(filled.count)/\(provider.credentialSchema.fields.count) fields"
        }
        guard let key = read(provider: provider), key.count >= 4 else {
            return "미연결"
        }
        let suffix = String(key.suffix(4))
        let dots = String(repeating: "•", count: min(key.count - 4, 12))
        return dots + suffix
    }

    // MARK: - Test

    /// 연결 테스트. 키 존재만으로 성공 처리하지 않습니다.
    /// AI provider는 실제 모델 목록 엔드포인트를 확인하고, 아직 검증기가 없는 provider는
    /// success=false/providerUnavailable로 남겨 UI가 connected를 표시하지 않게 합니다.
    func testConnection(provider: ExternalProvider) async -> CredentialTestResult {
        if [.naverNews, .dartDisclosure, .kmaWeather, .koreanLaw].contains(provider) {
            let fields = Dictionary(uniqueKeysWithValues: provider.credentialSchema.fields.map { field in
                (field.id, read(provider: provider, field: field) ?? "")
            })
            return await PublicAPIConnectorValidator.validate(
                PublicAPIValidationRequest(provider: provider, fields: fields)
            )
        }

        guard let key = read(provider: provider), !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return CredentialTestResult(
                provider: provider,
                success: false,
                failureCode: .missingAPIKey,
                message: "\(provider.displayName) 키가 아직 연결되지 않았어요."
            )
        }

        guard let llmProvider = llmProviderRawValue(for: provider) else {
            return CredentialTestResult(
                provider: provider,
                success: false,
                failureCode: .providerUnavailable,
                message: "\(provider.displayName) 실제 연결 테스트는 아직 준비 중입니다. 키는 저장됐지만 연결됨으로 표시하지 않습니다."
            )
        }

        do {
            let message = try await AIService.shared.validateKey(provider: llmProvider, apiKey: key)
            return CredentialTestResult(
                provider: provider,
                success: true,
                failureCode: nil,
                message: message
            )
        } catch {
            return CredentialTestResult(
                provider: provider,
                success: false,
                failureCode: Self.failureCode(from: error),
                message: error.localizedDescription
            )
        }
    }

    private func llmProviderRawValue(for provider: ExternalProvider) -> String? {
        switch provider {
        case .gemini:
            return LLMProvider.gemini.rawValue
        case .openAI:
            return LLMProvider.openAI.rawValue
        case .anthropic:
            return LLMProvider.claude.rawValue
        case .openRouter:
            return LLMProvider.openRouter.rawValue
        case .kmaWeather, .naverNews, .dartDisclosure, .koreanLaw, .publicDataPortal:
            return nil
        }
    }

    private static func failureCode(from error: Error) -> ConnectorFailureCode {
        let message = error.localizedDescription.lowercased()
        if message.contains("401") || message.contains("올바르지") || message.contains("invalid") || message.contains("unauthorized") {
            return .invalidAPIKey
        }
        if message.contains("403") || message.contains("권한") || message.contains("permission") {
            return .permissionDenied
        }
        if message.contains("429") || message.contains("한도") || message.contains("rate") {
            return .rateLimited
        }
        if message.contains("network") || message.contains("네트워크") || message.contains("internet") {
            return .networkError
        }
        if message.contains("500") || message.contains("server") || message.contains("서버") {
            return .providerUnavailable
        }
        return .responseParseFailed
    }

    private func keychainKey(provider: ExternalProvider, field: CredentialField) -> String {
        "\(provider.rawValue).\(field.keychainSuffix)"
    }
}

// MARK: - CredentialTestResult

struct CredentialTestResult: Sendable {
    let provider: ExternalProvider
    let success: Bool
    let failureCode: ConnectorFailureCode?
    let message: String
}
