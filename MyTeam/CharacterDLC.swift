import Foundation

struct CharacterDLC: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let role: String
    let description: String
    let specialty: [String]
    let personaPrompt: String
    let spriteAssetName: String
    let portraitAssetName: String?
    let previewVoiceAssetName: String?
    let bundledSkillIDs: [String]
    let recommendedProvider: String?
    let productID: String?
    let priceDisplay: String?
    let isBuiltIn: Bool
    let isPremium: Bool
    let isComingSoon: Bool
}
