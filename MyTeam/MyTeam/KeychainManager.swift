import Security
import Foundation

// MARK: - KeychainManager
// API 키를 macOS Keychain에 암호화 저장/조회합니다.
// UserDefaults 평문 저장 방식을 대체합니다.
enum KeychainManager {

    private static let service = "com.myteam.app"

    // MARK: - 저장
    @discardableResult
    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // 기존 항목이 있으면 먼저 삭제
        delete(key: key)

        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData:   data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - 조회
    static func load(key: String) -> String {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key,
            kSecMatchLimit:       kSecMatchLimitOne,
            kSecReturnData:       true,
            kSecReturnAttributes: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let dict = result as? [CFString: Any],
              let data = dict[kSecValueData] as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return "" }

        return value
    }

    // MARK: - 삭제
    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
