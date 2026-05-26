import Foundation

// MARK: - SkillAvailabilityResolver
// Round 246A-HOTFIX: 스킬별 실제 동작 가능 수준을 중앙에서 판단한다.
//
// 정책:
// - defaultEnabled=true여도 notes에 "미구현"이 있으면 assistOnly
// - 외부 API 없이 LLM만으로 동작하면 assistOnly
// - assistOnly는 자료를 주면 요약/정리 가능, API 직접 조회 안 함
//
// 확장: 새 스킬 추가 시 여기에 case 또는 notes 기준 추가.

enum SkillAvailabilityResolver {

    static func availability(for skill: SkillManifest) -> FeatureAvailability {
        // notes에 "미구현"이 있으면 assistOnly (모든 스킬 공통 규칙)
        if skill.notes?.contains(where: { $0.contains("미구현") }) == true {
            return .assistOnly
        }

        // 스킬 ID별 명시적 override
        switch skill.id {
        case "korean.dart":
            return .assistOnly
        case "korean.law-search":
            return .assistOnly
        case "korean.naver-news", "korean.naver-blog-research":
            return .assistOnly
        case "korean.ktx-booking":
            return .assistOnly
        case "korean.map-place", "korean.reservation-preparation":
            return .assistOnly
        case "korean.stock-info":
            return .assistOnly
        case "korean.scholarship":
            return .assistOnly
        case "korean.office-review-assist", "korean.file-image-assist":
            return .assistOnly
        case "korean.accounting-tax":
            return .assistOnly
        default:
            return .available
        }
    }

    /// assistOnly로 분류되는 스킬 ID 목록 (거버넌스 검증용)
    static var assistOnlySkillIDs: Set<String> {
        let baseIDs: Set<String> = [
            "korean.dart",
            "korean.law-search",
            "korean.naver-news",
            "korean.naver-blog-research",
            "korean.ktx-booking",
            "korean.map-place",
            "korean.reservation-preparation",
            "korean.stock-info",
            "korean.scholarship",
            "korean.office-review-assist",
            "korean.file-image-assist",
            "korean.accounting-tax"
        ]
        let allSkills = BuiltInKoreanSkills.all
        let notesBasedIDs = Set(allSkills
            .filter { skill in skill.notes?.contains(where: { $0.contains("미구현") }) == true }
            .map { $0.id })
        return baseIDs.union(notesBasedIDs)
    }

    /// assistOnly 스킬에 표시할 사용자 안내 메시지
    static func assistOnlyMessage(for skillID: String) -> String {
        switch skillID {
        case "korean.dart":
            return "제가 DART를 조회한 척하지는 않아요. 공시 PDF, 사업보고서 본문, 링크를 주시면 핵심 숫자와 위험 포인트를 카드로 정리해드릴게요."
        case "korean.law-search":
            return "최신 법령을 확인한 것처럼 단정하지 않습니다. 법령명이나 조항 내용을 주시면 쟁점과 확인할 부분을 정리해드릴게요."
        case "korean.naver-news", "korean.naver-blog-research":
            return "검색 결과를 꾸며내지 않습니다. 기사나 블로그 본문을 붙여주시면 요약·비교·초안으로 정리해드릴게요."
        case "korean.ktx-booking":
            return "제가 대신 로그인하거나 결제하진 않아요. 출발·도착·날짜·인원을 알려주시면 코레일톡에 바로 넣을 조건 카드로 정리해드릴게요."
        case "korean.map-place", "korean.reservation-preparation":
            return "제가 대신 예약하거나 개인정보를 제출하진 않아요. 장소명이나 링크를 주시면 비교 기준과 예약 전 확인 항목을 정리해드릴게요."
        case "korean.stock-info":
            return "매수·매도 판단을 확정하지는 않아요. 종목명, 기사, 공시를 주시면 숫자·이슈·리스크를 분리해 카드로 정리해드릴게요."
        case "korean.scholarship":
            return "최신 공고를 본 것처럼 단정하지 않습니다. 공고문이나 링크를 주시면 자격 조건과 준비 서류를 정리해드릴게요."
        default:
            return "제가 실제로 확인한 것처럼 꾸미지 않습니다. 자료를 주시면 정리·초안·검토 형태로 바로 도와드릴게요."
        }
    }
}
