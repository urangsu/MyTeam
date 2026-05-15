import Foundation

// MARK: - CharacterAssetAvailability
// Character 스프라이트 에셋의 준비 상태를 4단계로 분류한다.
// Release 노출 여부는 ReleaseVisibleCharacterPolicy가 결정한다.

enum CharacterAssetAvailability: String, Codable, Equatable, Sendable {
    /// 모든 required 스프라이트가 production-ready (non-placeholder)
    case productionReady

    /// 일부 스프라이트만 있으나 명시적 승인으로 Release 노출 허용
    case partialAllowed

    /// placeholder 에셋만 있음 — Release 대표 UI 숨김
    case placeholder

    /// 에셋 정보가 없거나 등록되지 않음
    case missing

    var isVisibleInRelease: Bool {
        switch self {
        case .productionReady, .partialAllowed: return true
        case .placeholder, .missing: return false
        }
    }

    var isDLCReady: Bool {
        self == .productionReady
    }

    var shortLabel: String {
        switch self {
        case .productionReady: return "✅ production"
        case .partialAllowed:  return "⚠️ partial"
        case .placeholder:     return "🔲 placeholder"
        case .missing:         return "❌ missing"
        }
    }
}
