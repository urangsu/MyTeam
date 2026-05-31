import Foundation
import Combine

// MARK: - CharacterAccessState

enum CharacterAccessState: Equatable {
    case owned
    case locked
    case comingSoon
}

// MARK: - CharacterUnlockState

/// 캐릭터 잠금 해제 상태 퍼시스턴스.
/// UserDefaults bool 단일 처리 대신 딕셔너리로 관리합니다.
/// StoreKit 결제가 구현되면 이 딕셔너리를 receipt 검증 결과로 덮어씁니다.
private struct CharacterUnlockStateStore {
    private static let key = "MyTeam.CharacterUnlockStates.v1"

    static func isUnlocked(characterID: String) -> Bool {
        let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Bool] ?? [:]
        return dict[characterID] ?? false
    }

    static func setUnlocked(characterID: String, unlocked: Bool) {
        var dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Bool] ?? [:]
        dict[characterID] = unlocked
        UserDefaults.standard.set(dict, forKey: key)
    }

    static func allUnlockedIDs() -> [String] {
        let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Bool] ?? [:]
        return dict.compactMap { $0.value ? $0.key : nil }
    }
}

// MARK: - CharacterEntitlementManager

/// 캐릭터 접근 권한을 관리합니다.
/// 현재는 isBuiltIn / isComingSoon 플래그 기반이며,
/// StoreKit 결제가 추가되면 purchase 검증 결과를 이 클래스에서 통합합니다.
///
/// ⚠️ 기존 캐릭터의 역할/말투/성격은 절대 수정하지 않습니다.
final class CharacterEntitlementManager: ObservableObject {
    static let shared = CharacterEntitlementManager()
    private init() {}

    // MARK: - Access State

    func accessState(for character: CharacterDLC) -> CharacterAccessState {
        if character.isBuiltIn { return .owned }
        if character.isComingSoon { return .comingSoon }
        // StoreKit 결제 또는 unlock 기록이 있으면 owned
        if CharacterUnlockStateStore.isUnlocked(characterID: character.id) { return .owned }
        return .locked
    }

    func isOwned(_ character: CharacterDLC) -> Bool {
        accessState(for: character) == .owned
    }

    // MARK: - Unlock (향후 StoreKit 연동용)

    /// 테스트 또는 StoreKit 결제 완료 후 호출합니다.
    /// App Store 심사 시 외부에서 직접 호출되지 않습니다.
    func markUnlocked(characterID: String) {
        CharacterUnlockStateStore.setUnlocked(characterID: characterID, unlocked: true)
        objectWillChange.send()
    }

    // MARK: - Stats

    var ownedCharacterIDs: [String] {
        CharacterUnlockStateStore.allUnlockedIDs()
    }

    var hasAnyPurchasedContent: Bool {
        !ownedCharacterIDs.isEmpty
    }
}

// MARK: - CharacterEntitlement (제품 카탈로그 skeleton)

/// 향후 App Store Connect에 등록할 인앱 구매 제품 정보.
/// StoreKit Product.products(for:)에 전달할 productID 목록입니다.
struct CharacterEntitlement {
    let characterID: String
    let productID: String        // App Store Connect 제품 ID
    let displayName: String
    let priceDisplay: String     // 출시 전: "출시 예정"

    static let catalog: [CharacterEntitlement] = [
        // 예: CharacterEntitlement(characterID: "luna_premium", productID: "com.myteam.character.luna_premium", displayName: "루나 프리미엄", priceDisplay: "출시 예정")
        // 실제 제품은 App Store Connect 등록 후 추가합니다.
    ]
}
