import Foundation
import Security

/// API 키 보안 관리 — Login Keychain (entitlement 불필요, -34018 없음)
/// kSecUseDataProtectionKeychain 제거: 개발 빌드에서 entitlement 없으면 -34018 발생
final class KeychainManager {
    static let shared = KeychainManager()
    private init() {}

    private static let service = "MyTeam.APIKeys"
    private static var memoryCache: [String: String] = [:] // 캐싱으로 프롬프트 방지

    // MARK: - Save
    @discardableResult
    static func save(key: String, value: String) -> Bool {
        memoryCache[key] = value // 캐시 업데이트
        
        guard let data = value.data(using: .utf8) else { return false }

        let searchQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let updateAttr: [String: Any] = [
            kSecValueData as String:        data,
            kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlock
        ]
        var status = SecItemUpdate(searchQuery as CFDictionary, updateAttr as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = searchQuery
            addQuery[kSecValueData as String]      = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        if status != errSecSuccess {
            print("[KeychainManager] ⚠️ save 실패 \(key): \(status)")
        }
        return status == errSecSuccess
    }

    // MARK: - Load
    static func load(key: String) -> String? {
        if let cached = memoryCache[key] {
            return cached
        }
        
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  kCFBooleanTrue!,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var ref: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &ref) == errSecSuccess,
           let data = ref as? Data,
           let value = String(data: data, encoding: .utf8), !value.isEmpty {
            memoryCache[key] = value // 로드 후 캐시
            return value
        }

        // 2. 이전 service 이름("MyTeam") 폴백
        let legacyQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: "MyTeam",
            kSecAttrAccount as String: key,
            kSecReturnData as String:  kCFBooleanTrue!,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        ref = nil
        if SecItemCopyMatching(legacyQuery as CFDictionary, &ref) == errSecSuccess,
           let data = ref as? Data,
           let value = String(data: data, encoding: .utf8), !value.isEmpty {
            print("[KeychainManager] 🔄 Legacy('MyTeam') → 현재 네임스페이스 마이그레이션: \(key)")
            save(key: key, value: value)
            return value
        }

        // 3. account-only 폴백 (구버전 항목)
        let accountQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  kCFBooleanTrue!,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        ref = nil
        if SecItemCopyMatching(accountQuery as CFDictionary, &ref) == errSecSuccess,
           let data = ref as? Data,
           let value = String(data: data, encoding: .utf8), !value.isEmpty {
            print("[KeychainManager] 🔄 AccountOnly → 현재 네임스페이스 마이그레이션: \(key)")
            save(key: key, value: value)
            return value
        }

        return nil
    }

    // MARK: - Delete
    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - UserDefaults 마이그레이션 (최초 1회)
    static func migrateFromUserDefaultsIfNeeded() {
        let migrationKey = "keychain_migrated_v3"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let keysToMigrate = ["geminiAPIKey", "claudeAPIKey", "openRouterAPIKey", "openAIAPIKey", "openaiAPIKey"]
        for key in keysToMigrate {
            if let plaintext = UserDefaults.standard.string(forKey: key), !plaintext.isEmpty {
                if save(key: key, value: plaintext) {
                    UserDefaults.standard.removeObject(forKey: key)
                    print("[KeychainManager] ✅ UserDefaults → Keychain 마이그레이션: \(key)")
                }
            }
        }
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
