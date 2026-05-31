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

    // MARK: - Read

    /// 지정 provider의 API 키를 Keychain에서 읽습니다.
    /// - Returns: 저장된 키, 없으면 nil
    func read(provider: ExternalProvider) -> String? {
        KeychainManager.load(key: provider.keychainKey)
    }

    /// 키가 존재하는지 여부
    func hasKey(for provider: ExternalProvider) -> Bool {
        guard let key = read(provider: provider) else { return false }
        return !key.isEmpty
    }

    // MARK: - Delete

    /// 지정 provider의 API 키를 Keychain에서 삭제합니다.
    @discardableResult
    func delete(provider: ExternalProvider) -> Bool {
        KeychainManager.delete(key: provider.keychainKey)
    }

    // MARK: - Mask

    /// UI 표시용 마스킹 문자열. 마지막 4자만 보이고 나머지는 •로 가립니다.
    /// 예: "sk-abc...XYZ1" → "••••••••••XYZ1"
    func masked(provider: ExternalProvider) -> String {
        guard let key = read(provider: provider), key.count >= 4 else {
            return "미연결"
        }
        let suffix = String(key.suffix(4))
        let dots = String(repeating: "•", count: min(key.count - 4, 12))
        return dots + suffix
    }

    // MARK: - Test (Stub)

    /// 연결 테스트. 현재는 키 존재 여부만 확인합니다.
    /// 실제 API 검증은 추후 구현 예정입니다.
    func testConnection(provider: ExternalProvider) async -> CredentialTestResult {
        guard hasKey(for: provider) else {
            return CredentialTestResult(
                provider: provider,
                success: false,
                failureCode: .missingAPIKey,
                message: "\(provider.displayName) 키가 아직 연결되지 않았어요."
            )
        }
        // TODO: 실제 API 검증 호출 추가 (다음 라운드)
        return CredentialTestResult(
            provider: provider,
            success: true,
            failureCode: nil,
            message: "키가 저장되어 있습니다. 실제 연결 테스트는 준비 중이에요."
        )
    }
}

// MARK: - CredentialTestResult

struct CredentialTestResult: Sendable {
    let provider: ExternalProvider
    let success: Bool
    let failureCode: ConnectorFailureCode?
    let message: String
}
