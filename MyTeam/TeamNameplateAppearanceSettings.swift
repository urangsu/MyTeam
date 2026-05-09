import SwiftUI

struct TeamNameplateColorPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let hex: String
}

enum TeamNameplateAppearanceSettings {
    static let enabledKey = "teamNameplateEnabled"
    static let colorHexKey = "teamNameplateColorHex"
    static let borderColorHexKey = "teamNameplateBorderColorHex"
    static let legacyEnabledKey = "showTeamName"
    static let legacyColorHexKey = "teamNameColor"

    static let defaultEnabled = true
    static let defaultColorHex = "transparent"
    static let defaultBorderColorHex = "transparent"
    static let colorPresets: [TeamNameplateColorPreset] = [
        .init(id: "transparent", name: "투명", hex: "transparent"),
        .init(id: "purple", name: "보라", hex: "#7C3AED"),
        .init(id: "blue", name: "블루", hex: "#2563EB"),
        .init(id: "slate", name: "슬레이트", hex: "#334155")
    ]
    static let borderColorPresets: [TeamNameplateColorPreset] = [
        .init(id: "transparent", name: "투명", hex: "transparent"),
        .init(id: "subtle", name: "기본선", hex: "#FFFFFF33"),
        .init(id: "accent", name: "포인트", hex: "#7C3AED")
    ]

    static func color(from hex: String) -> Color {
        let normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty || normalized == "transparent" || normalized == "clear" {
            return .clear
        }
        return Color(hex: hex) ?? .clear
    }

    static func isTransparent(_ hex: String) -> Bool {
        let normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty || normalized == "transparent" || normalized == "clear"
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

        if defaults.string(forKey: borderColorHexKey) == nil {
            defaults.set(defaultBorderColorHex, forKey: borderColorHexKey)
        }
    }
}
