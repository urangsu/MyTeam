import Foundation

// MARK: - ReleaseVisibleCharacterPolicy
// Release 빌드에서 어떤 캐릭터를 UI에 노출할지 결정하는 단일 정책 게이트.
//
// 정책:
//   Release:
//     - productionReady / partialAllowed 캐릭터만 보임
//     - placeholder / missing는 대표 UI·DLC·purchase UI에서 숨김
//     - DLC ready가 아니면 구매 UI 숨김
//   DEBUG:
//     - 전체 roster 모두 표시 가능 (개발 진단용)

enum ReleaseVisibleCharacterPolicy {

    // MARK: - Visibility

    /// Release 빌드에서 이 캐릭터를 대표 UI에 노출할지 여부
    static func isVisible(_ character: CharacterDLC) -> Bool {
        #if DEBUG
        return true  // DEBUG: 전체 표시
        #else
        if character.isBuiltIn {
            // built-in 캐릭터는 스프라이트 상태에 따라 결정
            let manifest = CharacterAssetRegistry.manifest(
                for: character.id,
                spriteName: character.spriteAssetName
            )
            return manifest.availability.isVisibleInRelease
        }
        // 프리미엄 캐릭터: isComingSoon이면 숨김
        return !character.isComingSoon
        #endif
    }

    /// Release 빌드에서 DLC 구매 버튼을 노출할지 여부
    static func isDLCPurchasable(_ character: CharacterDLC) -> Bool {
        #if DEBUG
        return character.isPremium  // DEBUG: 프리미엄이면 표시
        #else
        guard character.isPremium && !character.isComingSoon else { return false }
        let manifest = CharacterAssetRegistry.manifest(
            for: character.id,
            spriteName: character.spriteAssetName
        )
        return manifest.isDLCReady
        #endif
    }

    // MARK: - Filtered Lists

    /// Release에서 표시 가능한 built-in 캐릭터 목록
    static var visibleBuiltIn: [CharacterDLC] {
        CharacterCatalog.builtIn.filter { isVisible($0) }
    }

    /// Release에서 표시 가능한 프리미엄 캐릭터 목록
    static var visiblePremium: [CharacterDLC] {
        CharacterCatalog.premium.filter { isVisible($0) }
    }

    /// Release에서 표시 가능한 전체 캐릭터 목록
    static var visibleCharacters: [CharacterDLC] {
        visibleBuiltIn + visiblePremium
    }

    /// Release에서 구매 가능한 프리미엄 캐릭터 목록
    static var purchasablePremium: [CharacterDLC] {
        CharacterCatalog.premium.filter { isDLCPurchasable($0) }
    }

    // MARK: - Diagnostics

    struct PolicyReport: Sendable {
        let totalCharacters: Int
        let visibleCount: Int
        let hiddenCount: Int
        let purchasableCount: Int
        let placeholderCount: Int
        let productionReadyCount: Int

        var summary: String {
            "visible=\(visibleCount)/\(totalCharacters) purchasable=\(purchasableCount) placeholder=\(placeholderCount) production=\(productionReadyCount)"
        }
    }

    static var policyReport: PolicyReport {
        let all = CharacterCatalog.all
        let manifests = CharacterAssetRegistry.allManifests
        let visible = visibleCharacters
        let purchasable = purchasablePremium

        let placeholderCount = manifests.filter { $0.isPlaceholder }.count
        let productionReadyCount = manifests.filter { $0.availability == .productionReady }.count

        return PolicyReport(
            totalCharacters: all.count,
            visibleCount: visible.count,
            hiddenCount: all.count - visible.count,
            purchasableCount: purchasable.count,
            placeholderCount: placeholderCount,
            productionReadyCount: productionReadyCount
        )
    }
}
