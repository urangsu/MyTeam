import SwiftUI

struct KoreanTextMetricsResultCardView: View {
    let text: String
    let isDarkMode: Bool

    private var displayData: KoreanTextMetricsDisplayData? {
        KoreanTextMetricsService.parseResultText(text)
    }

    private var cardFill: Color {
        isDarkMode ? Color.white.opacity(0.08) : Color(red: 0.96, green: 0.97, blue: 1.0)
    }

    var body: some View {
        if let displayData {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("한국어 글자 수 세기")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(isDarkMode ? .white : .black)
                        Text("로컬 처리")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.green.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.green.opacity(0.14)))
                    }
                    Spacer()
                }

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ], spacing: 10) {
                    metricCell(title: "공백 포함", value: displayData.charactersWithSpaces)
                    metricCell(title: "공백 제외", value: displayData.charactersWithoutWhitespace)
                    metricCell(title: "UTF-8", value: displayData.utf8Bytes)
                    metricCell(title: "제출폼 기준", value: displayData.koreanFormBytes)
                    metricCell(title: "줄 수", value: displayData.lineCount)
                    metricCell(title: "문단 수", value: displayData.paragraphCount)
                }

                Text("제출폼 기준은 한글 2바이트, 영문/숫자 1바이트 근사값입니다.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(isDarkMode ? 0.22 : 0.16), lineWidth: 1)
            )
            .frame(maxWidth: 280, alignment: .leading)
        } else {
            Text(text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(isDarkMode ? .white : .black)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isDarkMode ? Color.white.opacity(0.11) : Color.black.opacity(0.07))
                )
                .frame(maxWidth: 280, alignment: .leading)
        }
    }

    private func metricCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(isDarkMode ? .white : .black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.black.opacity(0.14) : Color.white.opacity(0.85))
        )
    }
}
