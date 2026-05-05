import SwiftUI

// MARK: - SkillResultRendererView
/// 스킬 실행 결과를 공통으로 렌더링한다.
/// skillID를 보고 적절한 카드 콘텐츠를 반환한다.
/// 스킬이 처리 가능하지 않으면 일반 텍스트를 반환한다.
@ViewBuilder
func SkillResultRendererView(
    skillID: String?,
    text: String,
    isDarkMode: Bool,
    isUser: Bool
) -> some View {
    if let skillID = skillID {
        switch skillID {
        case "korean.character-count":
            if let parsed = KoreanTextMetricsService.parseResultText(text) {
                KoreanCharacterCountCardView(data: parsed)
            } else {
                fallbackTextContent(text: text, isDarkMode: isDarkMode, isUser: isUser)
            }
        default:
            fallbackTextContent(text: text, isDarkMode: isDarkMode, isUser: isUser)
        }
    } else {
        fallbackTextContent(text: text, isDarkMode: isDarkMode, isUser: isUser)
    }
}

// MARK: - Fallback Content
@ViewBuilder
private func fallbackTextContent(
    text: String,
    isDarkMode: Bool,
    isUser: Bool
) -> some View {
    Text(text)
        .font(.system(size: 12))
        .foregroundColor(isUser ? .white : (isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9)))
}

// MARK: - KoreanCharacterCountCardView
struct KoreanCharacterCountCardView: View {
    let data: KoreanTextMetricsDisplayData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Text("한국어 글자 수 세기")
                    .font(.headline)
                Text("로컬 처리")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(3)
                Spacer()
            }

            // Grid: 2 columns, 3 rows
            VStack(spacing: 8) {
                HStack(spacing: 20) {
                    MetricItem(label: "공백 포함", value: data.charactersWithSpaces)
                    MetricItem(label: "공백 제외", value: data.charactersWithoutWhitespace)
                }
                HStack(spacing: 20) {
                    MetricItem(label: "UTF-8", value: data.utf8Bytes)
                    MetricItem(label: "제출폼 기준", value: data.koreanFormBytes)
                }
                HStack(spacing: 20) {
                    MetricItem(label: "줄 수", value: data.lineCount)
                    MetricItem(label: "문단 수", value: data.paragraphCount)
                }
            }

            Divider()

            // Description
            Text("제출폼 기준은 한글 2바이트, 영문/숫자 1바이트 근사값입니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - MetricItem
private struct MetricItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(spacing: 20) {
        KoreanCharacterCountCardView(
            data: KoreanTextMetricsDisplayData(
                charactersWithSpaces: "42자",
                charactersWithoutWhitespace: "35자",
                utf8Bytes: "103 bytes",
                koreanFormBytes: "70 bytes",
                lineCount: "2줄",
                paragraphCount: "2개"
            )
        )
        .padding()

        Spacer()
    }
    .background(Color(NSColor.windowBackgroundColor))
}
