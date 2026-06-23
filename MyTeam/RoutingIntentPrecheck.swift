import Foundation

// MARK: - RoutingIntentPrecheck
// 메시지 텍스트 분석으로 tool-use 필요 여부를 결정한다.
enum RoutingIntentPrecheck {
    /// 한국어 + 영어 키워드로 tool-use 의도를 추론한다.
    nonisolated static func needsTool(_ text: String, hasAttachments: Bool = false) -> Bool {
        if hasAttachments { return true }
        let normalized = text.lowercased()
        if let intent = KSkillAssistRuntime.detectIntent(userMessage: normalized) {
            switch intent {
            case .stockInfoAssist, .dartDisclosureAssist, .naverNewsAssist, .naverBlogResearchAssist,
                 .lawSearchAssist, .scholarshipAssist, .ktxBookingAssist, .mapPlaceAssist, .reservationPreparation:
                return true
            default:
                break
            }
        }
        if ToolPolicy.evaluate(normalized).needsTool { return true }
        let keywords = [
            "검색", "찾아", "파일", "실행", "열어", "계산", "웹",
            "공시", "지도", "길찾기", "예약", "ktx", "srt",
            "메일", "pdf", "이미지", "캡처", "계좌", "거래내역",
            "search", "find", "file", "run", "execute", "open", "calculate", "web",
            "pdf", "mail", "email", "map", "route", "reservation",
            "코드 실행", "터미널", "code run"
        ]
        return keywords.contains { normalized.contains($0.lowercased()) }
    }
}
