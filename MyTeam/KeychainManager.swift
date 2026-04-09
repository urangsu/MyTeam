import Foundation
import Security

/// 군사급 API 키 보안 관리를 위한 Keychain Manager
final class KeychainManager {
    static let shared = KeychainManager()
    private init() {}
    
    @discardableResult
    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }
    
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    /// UserDefaults에 평문으로 저장된 API 키를 Keychain으로 1회 마이그레이션.
    /// 앱 최초 부팅 또는 업그레이드 직후 한 번만 실행됨.
    static func migrateFromUserDefaultsIfNeeded() {
        let migrationKey = "keychain_migrated_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let keysToMigrate = [
            "geminiAPIKey", "claudeAPIKey", "openRouterAPIKey", "openaiAPIKey"
        ]

        for key in keysToMigrate {
            if let plaintext = UserDefaults.standard.string(forKey: key), !plaintext.isEmpty {
                save(key: key, value: plaintext)
                UserDefaults.standard.removeObject(forKey: key)
                print("[KeychainManager] ✅ UserDefaults → Keychain 마이그레이션 완료: \(key)")
            }
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
