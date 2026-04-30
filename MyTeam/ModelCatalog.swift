import Foundation

enum ModelCatalog {
    static let defaultTTSModelId = "aufklarer/Qwen3-TTS-12Hz-1.7B-Base-MLX-4bit"
    static let ttsModelUserDefaultsKey = "ttsModelId"

    static func resolvedTTSModelId() -> String {
        let stored = UserDefaults.standard.string(forKey: ttsModelUserDefaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return stored?.isEmpty == false ? stored! : defaultTTSModelId
    }
}
