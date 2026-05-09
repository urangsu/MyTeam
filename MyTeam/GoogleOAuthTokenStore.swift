import Foundation
import Security

protocol GoogleOAuthTokenStoring {
    func hasToken(for provider: AssistantConnector.Provider) -> Bool
    func loadToken(for provider: AssistantConnector.Provider) throws -> GoogleOAuthToken?
    func saveToken(_ token: GoogleOAuthToken, for provider: AssistantConnector.Provider) throws
    func deleteToken(for provider: AssistantConnector.Provider) throws
}

enum GoogleOAuthTokenStoreError: Error {
    case notFound
    case keychainError(OSStatus)
    case encodingFailed
    case decodingFailed
}

final class GoogleOAuthTokenStore: GoogleOAuthTokenStoring {
    static let shared = GoogleOAuthTokenStore()

    private let service = "MyTeam.GoogleOAuthToken"

    private init() {}

    func hasToken(for provider: AssistantConnector.Provider) -> Bool {
        (try? loadToken(for: provider)) != nil
    }

    func loadToken(for provider: AssistantConnector.Provider) throws -> GoogleOAuthToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw GoogleOAuthTokenStoreError.keychainError(status)
        }
        guard let data = item as? Data else {
            throw GoogleOAuthTokenStoreError.decodingFailed
        }
        return try JSONDecoder().decode(GoogleOAuthToken.self, from: data)
    }

    func saveToken(_ token: GoogleOAuthToken, for provider: AssistantConnector.Provider) throws {
        guard let data = try? JSONEncoder().encode(token) else {
            throw GoogleOAuthTokenStoreError.encodingFailed
        }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemCopyMatching(baseQuery as CFDictionary, nil)
        if status == errSecSuccess {
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw GoogleOAuthTokenStoreError.keychainError(updateStatus)
            }
        } else if status == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery.merge(attributes) { _, new in new }
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw GoogleOAuthTokenStoreError.keychainError(addStatus)
            }
        } else {
            throw GoogleOAuthTokenStoreError.keychainError(status)
        }
    }

    func deleteToken(for provider: AssistantConnector.Provider) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw GoogleOAuthTokenStoreError.keychainError(status)
        }
    }
}
