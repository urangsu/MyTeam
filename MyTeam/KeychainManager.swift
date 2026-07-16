import Foundation
import Security

enum KeychainAccessPolicy {
    nonisolated static func allowsAccess(arguments: [String]) -> Bool {
        !QARuntimeProfile.isEnabled(arguments: arguments)
    }

    nonisolated static var allowsCurrentProcessAccess: Bool {
        allowsAccess(arguments: ProcessInfo.processInfo.arguments)
    }
}

nonisolated enum KeychainMutationPolicy {
    static func saveSucceeded(status: OSStatus) -> Bool {
        status == errSecSuccess
    }

    static func deleteSucceeded(status: OSStatus) -> Bool {
        status == errSecSuccess || status == errSecItemNotFound
    }
}

/// API 키 보안 관리 — Login Keychain (entitlement 불필요, -34018 없음)
/// kSecUseDataProtectionKeychain 제거: 개발 빌드에서 entitlement 없으면 -34018 발생
nonisolated final class KeychainManager {
    static let shared = KeychainManager()
    private init() {}

    private static let service = "MyTeam.APIKeys"
    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var memoryCache: [String: String] = [:]

    // MARK: - Save
    @discardableResult
    static func save(key: String, value: String) -> Bool {
        guard KeychainAccessPolicy.allowsCurrentProcessAccess else { return false }
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
        if !KeychainMutationPolicy.saveSucceeded(status: status) {
            print("[KeychainManager] ⚠️ save 실패 \(key): \(status)")
        } else {
            storeCachedValue(value, for: key)
        }
        return KeychainMutationPolicy.saveSucceeded(status: status)
    }

    // MARK: - Load
    static func load(key: String) -> String? {
        guard KeychainAccessPolicy.allowsCurrentProcessAccess else { return nil }
        if let cached = cachedValue(for: key) {
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
            storeCachedValue(value, for: key)
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
            storeCachedValue(value, for: key)
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
            storeCachedValue(value, for: key)
            save(key: key, value: value)
            return value
        }

        return nil
    }

    // MARK: - Delete
    @discardableResult
    static func delete(key: String) -> Bool {
        guard KeychainAccessPolicy.allowsCurrentProcessAccess else { return true }
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        let succeeded = KeychainMutationPolicy.deleteSucceeded(status: status)
        if succeeded {
            removeCachedValue(for: key)
        }
        return succeeded
    }

    // MARK: - UserDefaults 마이그레이션 (최초 1회)
    @discardableResult
    static func migrateFromUserDefaultsIfNeeded() -> Bool {
        guard KeychainAccessPolicy.allowsCurrentProcessAccess else { return false }
        let migrationKey = "keychain_migrated_v3"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return true }

        let keysToMigrate = ["geminiAPIKey", "claudeAPIKey", "openRouterAPIKey", "openAIAPIKey", "openaiAPIKey"]
        var migrationSucceeded = true
        for key in keysToMigrate {
            if let plaintext = UserDefaults.standard.string(forKey: key), !plaintext.isEmpty {
                if save(key: key, value: plaintext) {
                    UserDefaults.standard.removeObject(forKey: key)
                    print("[KeychainManager] ✅ UserDefaults → Keychain 마이그레이션: \(key)")
                } else {
                    migrationSucceeded = false
                }
            }
        }
        if migrationSucceeded {
            UserDefaults.standard.set(true, forKey: migrationKey)
        }
        return migrationSucceeded
    }

    private static func cachedValue(for key: String) -> String? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return memoryCache[key]
    }

    private static func storeCachedValue(_ value: String, for key: String) {
        cacheLock.lock()
        memoryCache[key] = value
        cacheLock.unlock()
    }

    private static func removeCachedValue(for key: String) {
        cacheLock.lock()
        memoryCache.removeValue(forKey: key)
        cacheLock.unlock()
    }
}
