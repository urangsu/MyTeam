import Foundation

enum AppLaunchSkillType: String, Codable, CaseIterable {
    case appStoreCopy
    case onboardingCopy
    case launchChecklist
    case monetizationReview

    var skillID: String {
        switch self {
        case .appStoreCopy: return "korean.app-store-copy"
        case .onboardingCopy: return "korean.onboarding-copy"
        case .launchChecklist: return "korean.launch-checklist"
        case .monetizationReview: return "korean.monetization-review"
        }
    }

    var displayName: String {
        switch self {
        case .appStoreCopy: return "앱스토어 설명문"
        case .onboardingCopy: return "온보딩 문구"
        case .launchChecklist: return "출시 체크리스트"
        case .monetizationReview: return "수익화 점검표"
        }
    }

    var defaultFilenameSuffix: String {
        switch self {
        case .appStoreCopy: return "앱스토어_설명문"
        case .onboardingCopy: return "온보딩_문구"
        case .launchChecklist: return "출시_체크리스트"
        case .monetizationReview: return "수익화_점검표"
        }
    }
}
