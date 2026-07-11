import Foundation
import Combine

// MARK: - CharacterAccessState

enum CharacterAccessState: Equatable {
    case owned
    case locked
    case comingSoon
}

// MARK: - CharacterEntitlementManager

/// 캐릭터 접근 권한을 관리합니다.
/// 기본 캐릭터 또는 StoreKit이 검증한 현재 entitlement만 소유로 인정합니다.
///
/// ⚠️ 기존 캐릭터의 역할/말투/성격은 절대 수정하지 않습니다.
@MainActor
final class CharacterEntitlementManager: ObservableObject {
    static let shared = CharacterEntitlementManager()
    private init() {}

    // MARK: - Access State

    func accessState(for character: CharacterDLC) -> CharacterAccessState {
        if character.isBuiltIn { return .owned }
        if character.isComingSoon { return .comingSoon }
        if let productID = character.productID,
           PurchaseManager.shared.isPurchased(productID) {
            return .owned
        }
        return .locked
    }

    func isOwned(_ character: CharacterDLC) -> Bool {
        accessState(for: character) == .owned
    }

    // MARK: - Stats

    var ownedCharacterIDs: [String] {
        CharacterCatalog.premium.compactMap { character in
            guard let productID = character.productID,
                  PurchaseManager.shared.isPurchased(productID) else { return nil }
            return character.id
        }
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
