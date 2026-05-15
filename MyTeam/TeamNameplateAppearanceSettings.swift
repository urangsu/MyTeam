import SwiftUI

// MARK: - TeamNameplatePalette
// 팀 명패 배경색 팔레트 — 고정 8색 + 투명
enum TeamNameplatePalette: String, CaseIterable, Codable {
    case clear      = "clear"
    case slate      = "slate"
    case cream      = "cream"
    case blue       = "blue"
    case mint       = "mint"
    case lavender   = "lavender"
    case peach      = "peach"
    case graphite   = "graphite"
    case purple     = "purple"

    var displayName: String {
        switch self {
        case .clear:    return "투명"
        case .slate:    return "슬레이트"
        case .cream:    return "크림"
        case .blue:     return "블루"
        case .mint:     return "민트"
        case .lavender: return "라벤더"
        case .peach:    return "피치"
        case .graphite: return "그라파이트"
        case .purple:   return "보라"
        }
    }

    var color: Color {
        switch self {
        case .clear:    return .clear
        case .slate:    return Color(hex: "#334155") ?? .gray
        case .cream:    return Color(hex: "#FFF8E7") ?? .yellow
        case .blue:     return Color(hex: "#2563EB") ?? .blue
        case .mint:     return Color(hex: "#10B981") ?? .green
        case .lavender: return Color(hex: "#7C3AED") ?? .purple
        case .peach:    return Color(hex: "#FB923C") ?? .orange
        case .graphite: return Color(hex: "#1F2937") ?? .black
        case .purple:   return Color(hex: "#9333EA") ?? .purple
        }
    }

    /// 레거시 hex 값에서 가장 가까운 팔레트 항목으로 변환 (마이그레이션용)
    static func nearest(fromHex hex: String) -> TeamNameplatePalette {
        let n = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if n.isEmpty || n == "transparent" || n == "clear" { return .clear }
        if n.contains("334155") { return .slate }
        if n.contains("2563eb") { return .blue }
        if n.contains("7c3aed") || n.contains("9333ea") { return .purple }
        return .clear
    }
}

// MARK: - TeamNameplateBorderMode
enum TeamNameplateBorderMode: String, Codable, CaseIterable {
    case none   = "none"
    case subtle = "subtle"

    var displayName: String {
        switch self {
        case .none:   return "없음"
        case .subtle: return "있음"
        }
    }
}

// MARK: - TeamNameplateAppearanceSettings
enum TeamNameplateAppearanceSettings {
    // MARK: Keys
    static let enabledKey      = "teamNameplateEnabled"
    static let paletteKey      = "teamNameplatePalette"       // 신규
    static let borderModeKey   = "teamNameplateBorderMode"    // 신규

    // Legacy keys (마이그레이션 전용)
    static let legacyEnabledKey     = "showTeamName"
    static let legacyColorHexKey    = "teamNameColor"
    static let legacyColorHexKey2   = "teamNameplateColorHex"
    static let legacyBorderHexKey   = "teamNameplateBorderColorHex"

    // MARK: Defaults
    static let defaultEnabled    = true
    static let defaultPalette    = TeamNameplatePalette.clear
    static let defaultBorderMode = TeamNameplateBorderMode.none

    // MARK: Helper — palette to Color
    static func resolvedColor(palette: TeamNameplatePalette) -> Color {
        palette.color
    }

    static func hasBorder(_ mode: TeamNameplateBorderMode) -> Bool {
        mode == .subtle
    }

    // MARK: - Migration
    static func migrateLegacyValuesIfNeeded() {
        let defaults = UserDefaults.standard

        // enabled
        if defaults.object(forKey: enabledKey) == nil {
            if defaults.object(forKey: legacyEnabledKey) != nil {
                defaults.set(defaults.bool(forKey: legacyEnabledKey), forKey: enabledKey)
            } else {
                defaults.set(defaultEnabled, forKey: enabledKey)
            }
        }

        // palette (from legacy hex)
        if defaults.string(forKey: paletteKey) == nil {
            let legacyHex = defaults.string(forKey: legacyColorHexKey2)
                ?? defaults.string(forKey: legacyColorHexKey)
                ?? ""
            let migrated = TeamNameplatePalette.nearest(fromHex: legacyHex)
            defaults.set(migrated.rawValue, forKey: paletteKey)
        }

        // border mode (from legacy border hex)
        if defaults.string(forKey: borderModeKey) == nil {
            let legacyBorder = defaults.string(forKey: legacyBorderHexKey) ?? ""
            let n = legacyBorder.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let migrated: TeamNameplateBorderMode = (n.isEmpty || n == "transparent" || n == "clear") ? .none : .subtle
            defaults.set(migrated.rawValue, forKey: borderModeKey)
        }
    }
}
