import SwiftUI

enum TeamNameplateAppearanceSettings {
    static let enabledKey = "teamNameplateEnabled"
    static let colorHexKey = "teamNameplateColorHex"
    static let legacyEnabledKey = "showTeamName"
    static let legacyColorHexKey = "teamNameColor"

    static let defaultEnabled = true
    static let defaultColorHex = "#7C3AED"

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
