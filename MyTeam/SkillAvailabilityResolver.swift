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
        if skill.notes.contains(where: { $0.contains("미구현") }) {
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
        default:
            return .available
        }
    }

    /// assistOnly 스킬에 표시할 사용자 안내 메시지
    static func assistOnlyMessage(for skillID: String) -> String {
        switch skillID {
        case "korean.dart":
            return "DART API 직접 조회는 아직 연결 전입니다. 종목명, 공시 PDF, 사업보고서 내용을 주시면 공시 요약 형식으로 정리해드릴 수 있어요."
        case "korean.law-search":
            return "법령 검색 API는 아직 연결 전입니다. 법령명이나 조항 내용을 주시면 분석·정리해드릴 수 있어요."
        case "korean.naver-news", "korean.naver-blog-research":
            return "뉴스/블로그 API는 아직 연결 전입니다. 기사 내용을 붙여 주시면 요약·분석해드릴 수 있어요."
        case "korean.ktx-booking":
            return "KTX/SRT 자동 예매는 지원하지 않습니다. 조건을 알려주시면 예매 전 체크리스트를 만들어드릴게요."
        case "korean.map-place", "korean.reservation-preparation":
            return "지도 직접 검색은 아직 연결 전입니다. 장소명이나 링크를 주시면 비교 기준과 예약 체크리스트를 정리해드릴게요."
        case "korean.stock-info":
            return "실시간 시세 조회는 아직 연결 전입니다. 종목명과 자료를 주시면 지표 체크리스트를 정리해드릴게요."
        case "korean.scholarship":
            return "복지로/장학금나라 직접 조회는 아직 연결 전입니다. 자격 조건과 서류 체크리스트를 정리해드릴 수 있어요."
        default:
            return "직접 실행은 아직 연결 전입니다. 자료를 주시면 정리·초안·검토 형태로 도와드릴게요."
        }
    }
}
