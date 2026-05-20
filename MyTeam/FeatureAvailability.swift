import Foundation

// MARK: - FeatureAvailability
// Round 246A-HOTFIX: BuiltInKoreanSkills 내부 enum에서 분리 → 독립 파일.
// 스킬/기능이 실제로 어느 수준까지 동작하는지 명시.
//
// fake available(❌) 제거, assistOnly(✅) 명시.
// 실제 판단은 SkillAvailabilityResolver를 통해 일원화.

enum FeatureAvailability: String, Codable, Equatable {
    case available      // 실제 동작 (외부 API 연결됨)
    case assistOnly     // LLM 보조만 가능, 외부 API 미연결
    case draftOnly      // 초안 작성만 가능 (실행 없음)
    case approvalBound  // 사용자 승인 후 실행 가능 (246B 연결 예정)
    case planned        // 개발 예정, directChat pivot
    case hidden         // 사용자에게 비공개
    case blocked        // 정책상 차단 (하드 블록)
}
