import Foundation

// MARK: - CharacterAssetManifest
// 개별 캐릭터의 스프라이트 에셋 완성도를 선언적으로 기록한다.
// CharacterCatalog 등록과 별도로 에셋 상태를 추적하기 위해 존재한다.

struct CharacterAssetManifest: Codable, Equatable, Sendable {
    let characterID: String
    let hasIdleSprite: Bool
    let hasThinkingSprite: Bool
    let hasWorkingSprite: Bool
    let hasSuccessSprite: Bool
    let hasSmallIcon: Bool
    let hasScreenshotPose: Bool

    /// 이 캐릭터가 placeholder 에셋만 있는지 여부
    var isPlaceholder: Bool {
        !hasIdleSprite && !hasWorkingSprite && !hasSuccessSprite
    }

    /// 모든 6가지 DLC 조건 중 에셋 조건(Condition 1)을 충족하는지
    var isDLCReady: Bool {
        hasIdleSprite && hasWorkingSprite && hasSuccessSprite && hasSmallIcon
    }

    /// 에셋 가용성 등급 계산
    var availability: CharacterAssetAvailability {
        if isDLCReady && hasScreenshotPose {
            return .productionReady
        } else if hasIdleSprite || hasWorkingSprite {
            // 일부 스프라이트 있음 — 명시적 승인 필요
            return .partialAllowed
        } else if isPlaceholder {
            return .placeholder
        } else {
            return .missing
        }
    }
}

// MARK: - CharacterAssetRegistry
// 코드 기반 에셋 manifest 조회. 실제 에셋 파일 존재 여부는 별도 검증.

enum CharacterAssetRegistry {

    // 에셋 이름에 "_placeholder"가 포함되면 placeholder로 판단하는 단순 휴리스틱.
    // v1.0 기준: 치코만 production sprite 보유.
    static func manifest(for characterID: String, spriteName: String) -> CharacterAssetManifest {
        let isProductionSprite = !spriteName.contains("_placeholder") && !spriteName.isEmpty

        switch characterID {
        case "chiko":
            // 치코: 기본 스프라이트 있음 — "치코" (non-placeholder)
            return CharacterAssetManifest(
                characterID: characterID,
                hasIdleSprite: isProductionSprite,
                hasThinkingSprite: false,       // 아직 미제작
                hasWorkingSprite: false,         // 아직 미제작
                hasSuccessSprite: false,         // 아직 미제작
                hasSmallIcon: isProductionSprite,
                hasScreenshotPose: false         // 아직 미제작
            )
        default:
            // 나머지 캐릭터: placeholder 또는 없음
            return CharacterAssetManifest(
                characterID: characterID,
                hasIdleSprite: false,
                hasThinkingSprite: false,
                hasWorkingSprite: false,
                hasSuccessSprite: false,
                hasSmallIcon: false,
                hasScreenshotPose: false
            )
        }
    }

    /// CharacterCatalog.all 기반으로 모든 캐릭터의 manifest를 반환
    static var allManifests: [CharacterAssetManifest] {
        CharacterCatalog.all.map { character in
            manifest(for: character.id, spriteName: character.spriteAssetName)
        }
    }
}
