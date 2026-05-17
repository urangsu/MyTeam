import Foundation

// MARK: - CharacterSpriteManifest
// 캐릭터별 스프라이트 시트 명세.
// 런타임 로딩은 CharacterSpriteScene이 직접 담당한다.
// 이 struct는 정적 검수(validator/preflight)와 문서 생성에 사용한다.

struct CharacterSpriteManifest: Codable, Equatable, Sendable {
    let characterID: String
    let displayName: String
    let requiredStates: [String]      // 반드시 있어야 하는 AnimationState rawValue
    let optionalStates: [String]      // 있으면 더 좋은 상태
    let fileConvention: String        // 파일명 패턴 설명
    let fallbackImageName: String     // xcassets 프로필 이미지 (스프라이트 없을 때)
    let runtimePath: String           // Bundle.main.resourcePath 기준 상대 경로
    let releaseVisible: Bool          // Release 빌드에서 노출 여부

    // MARK: - 공장 메서드

    static let chiko = CharacterSpriteManifest(
        characterID: "치코",
        displayName: "치코",
        requiredStates: [
            "idle",
            "typing",
            "thinking",
            "speaking",
            "greeting",
            "joy",
            "sad",
            "confused",
            "drag",
            "landing",
            "clockin",
            "backwork",
            "sleeping"
        ],
        optionalStates: [
            "idle_loop",
            "typing_return",
            "agree",
            "angry",
            "disagree",
            "praise",
            "resting",
            "clockout",
            "drop"
        ],
        fileConvention: "{characterID}_{state}_{index:03d}.png (예: 치코_idle_001.png)",
        fallbackImageName: "치코_profile",
        runtimePath: "Sprites/치코",
        releaseVisible: true
    )

    static let sena = CharacterSpriteManifest(
        characterID: "세나",
        displayName: "세나",
        requiredStates: ["idle", "typing", "greeting", "joy"],
        optionalStates: ["sad", "confused", "thinking"],
        fileConvention: "{characterID}_{state}_{index:03d}.png (예: 세나_idle_001.png)",
        fallbackImageName: "세나_profile",
        runtimePath: "Sprites/세나",
        releaseVisible: false
    )

    static let kai = CharacterSpriteManifest(
        characterID: "카이",
        displayName: "카이",
        requiredStates: ["idle", "typing", "greeting", "joy"],
        optionalStates: ["sad", "confused", "thinking"],
        fileConvention: "{characterID}_{state}_{index:03d}.png (예: 카이_idle_001.png)",
        fallbackImageName: "카이_profile",
        runtimePath: "Sprites/카이",
        releaseVisible: false
    )

    static let yuna = CharacterSpriteManifest(
        characterID: "유나",
        displayName: "유나",
        requiredStates: ["idle", "typing", "greeting", "joy"],
        optionalStates: ["sad", "confused", "thinking"],
        fileConvention: "{characterID}_{state}_{index:03d}.png (예: 유나_idle_001.png)",
        fallbackImageName: "유나_profile",
        runtimePath: "Sprites/유나",
        releaseVisible: false
    )

    /// 모든 캐릭터 명세
    static let all: [CharacterSpriteManifest] = [.chiko, .sena, .kai, .yuna]

    /// Release에서 표시할 캐릭터만
    static var releaseVisibleManifests: [CharacterSpriteManifest] {
        all.filter { $0.releaseVisible }
    }
}
