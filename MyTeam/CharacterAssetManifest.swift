import Foundation

struct CharacterAssetManifest: Codable, Equatable, Sendable {
    let characterID: String
    let hasIdleSprite: Bool
    let hasThinkingSprite: Bool
    let hasWorkingSprite: Bool
    let hasSuccessSprite: Bool
    let hasSmallIcon: Bool
    let hasScreenshotPose: Bool
    let isPlaceholder: Bool
    let isDLCReady: Bool

    enum CodingKeys: String, CodingKey {
        case characterID = "character_id"
        case hasIdleSprite = "has_idle_sprite"
        case hasThinkingSprite = "has_thinking_sprite"
        case hasWorkingSprite = "has_working_sprite"
        case hasSuccessSprite = "has_success_sprite"
        case hasSmallIcon = "has_small_icon"
        case hasScreenshotPose = "has_screenshot_pose"
        case isPlaceholder = "is_placeholder"
        case isDLCReady = "is_dlc_ready"
    }
}
