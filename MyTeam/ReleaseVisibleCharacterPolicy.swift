import Foundation

enum ReleaseVisibleCharacterPolicy {
    static func isVisibleInRelease(_ manifest: CharacterAssetManifest) -> Bool {
        if manifest.isPlaceholder { return false }
        return manifest.hasIdleSprite || manifest.hasWorkingSprite
    }

    static func isPurchasableInRelease(_ manifest: CharacterAssetManifest) -> Bool {
        manifest.isDLCReady && !manifest.isPlaceholder
    }

    static func isEligibleForScreenshot(_ manifest: CharacterAssetManifest) -> Bool {
        manifest.hasScreenshotPose && !manifest.isPlaceholder
    }

    static func availabilityStatus(_ manifest: CharacterAssetManifest) -> CharacterAssetAvailability {
        if manifest.isPlaceholder {
            return .placeholder
        }
        let assetCount = [
            manifest.hasIdleSprite,
            manifest.hasThinkingSprite,
            manifest.hasWorkingSprite,
            manifest.hasSuccessSprite,
            manifest.hasSmallIcon,
            manifest.hasScreenshotPose
        ].filter { $0 }.count

        if assetCount == 6 {
            return .productionReady
        } else if assetCount > 0 {
            return .partial
        } else {
            return .missing
        }
    }
}
