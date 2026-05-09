import SwiftUI

struct TeamNameplateColorPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let hex: String
}

enum TeamNameplateAppearanceSettings {
    static let enabledKey = "teamNameplateEnabled"
    static let colorHexKey = "teamNameplateColorHex"
    static let legacyEnabledKey = "showTeamName"
    static let legacyColorHexKey = "teamNameColor"

    static let defaultEnabled = true
    static let defaultColorHex = "#7C3AED"
    static let colorPresets: [TeamNameplateColorPreset] = [
        .init(id: "purple", name: "보라", hex: "#7C3AED"),
        .init(id: "blue", name: "블루", hex: "#2563EB"),
        .init(id: "cyan", name: "시안", hex: "#0891B2"),
        .init(id: "green", name: "그린", hex: "#16A34A"),
        .init(id: "amber", name: "앰버", hex: "#F59E0B"),
        .init(id: "rose", name: "로즈", hex: "#E11D48"),
        .init(id: "slate", name: "슬레이트", hex: "#334155"),
        .init(id: "black", name: "블랙", hex: "#111827")
    ]

    static func color(from hex: String) -> Color {
        Color(hex: hex) ?? .purple
    }

    static func migrateLegacyValuesIfNeeded() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: enabledKey) == nil {
            if defaults.object(forKey: legacyEnabledKey) != nil {
                defaults.set(defaults.bool(forKey: legacyEnabledKey), forKey: enabledKey)
            } else {
                defaults.set(defaultEnabled, forKey: enabledKey)
            }
        }

        if defaults.string(forKey: colorHexKey) == nil {
            if let legacy = defaults.string(forKey: legacyColorHexKey), !legacy.isEmpty {
                defaults.set(legacy, forKey: colorHexKey)
            } else {
                defaults.set(defaultColorHex, forKey: colorHexKey)
            }
        }
    }
}
