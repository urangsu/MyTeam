import SwiftUI

// MARK: - SkillResultRendererView
/// 스킬 실행 결과를 공통으로 렌더링한다.
/// skillID를 보고 적절한 카드 콘텐츠를 반환한다.
/// 스킬이 처리 가능하지 않으면 일반 텍스트를 반환한다.
struct SkillResultRendererView: View {
    let skillID: String?
    let text: String
    let isDarkMode: Bool
    let isUser: Bool

    var body: some View {
        if let skillID = skillID {
            switch skillID {
            case "korean.character-count":
                // TODO: Consider custom card vs KoreanTextMetricsResultCardView
                KoreanTextMetricsResultCardView(text: text, isDarkMode: isDarkMode)

            // TODO: korean.spell-check result card
            // TODO: korean.privacy-terms artifact card
            // TODO: runtime.diagnostics card
            // TODO: korean.accounting-tax summary card

            default:
                fallbackContent
            }
        } else {
            fallbackContent
        }
    }

    @ViewBuilder
    private var fallbackContent: some View {
        if isUser {
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.white)
        } else {
            MarkdownTextView(
                text: text,
                isDarkMode: isDarkMode
            )
        }
    }
}
