import SwiftUI

struct SpellCheckResultCardView: View {
    let text: String
    let isDarkMode: Bool

    private var parsed: SpellCheckParsed { SpellCheckParsed(text: text) }

    private var cardFill: Color {
        isDarkMode ? Color.white.opacity(0.08) : Color(red: 1.0, green: 0.97, blue: 0.94)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            if !parsed.correctedText.isEmpty {
                correctedSection
            }
            if !parsed.corrections.isEmpty {
                correctionsTable
            }
            if parsed.correctedText.isEmpty && parsed.corrections.isEmpty {
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(isDarkMode ? .white : .black)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(cardFill))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(isDarkMode ? 0.22 : 0.18), lineWidth: 1))
        .frame(maxWidth: 320, alignment: .leading)
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orange)
                    Text("한국어 맞춤법 검사")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isDarkMode ? .white : .black)
                }
                Text("AI 교정")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.orange.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange.opacity(0.14)))
            }
            Spacer()
            if !parsed.corrections.isEmpty {
                Text("\(parsed.corrections.count)건 발견")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
            }
        }
    }

    private var correctedSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("교정 결과")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Text(parsed.correctedText)
                .font(.system(size: 13))
                .foregroundColor(isDarkMode ? .white : .black)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.08)))
                .textSelection(.enabled)
        }
    }

    private var correctionsTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("변경 항목")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            ForEach(parsed.corrections.indices, id: \.self) { idx in
                let c = parsed.corrections[idx]
                HStack(alignment: .top, spacing: 8) {
                    Text(c.original)
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                        .strikethrough()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(c.corrected)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green.opacity(0.9))
                    if !c.reason.isEmpty {
                        Spacer()
                        Text(c.reason)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 4)
                if idx < parsed.corrections.count - 1 {
                    Divider().opacity(0.4)
                }
            }
        }
    }
}

// MARK: - Parser

private struct SpellCheckParsed {
    struct Correction {
        let original: String
        let corrected: String
        let reason: String
    }

    let correctedText: String
    let corrections: [Correction]

    init(text: String) {
        var corrected = ""
        var corrections: [Correction] = []

        let lines = text.components(separatedBy: "\n")
        var inCorrectedBlock = false
        var inTableBlock = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().contains("교정 결과") || trimmed.lowercased().contains("corrected") {
                inCorrectedBlock = true
                inTableBlock = false
                continue
            }
            if trimmed.lowercased().contains("변경") || trimmed.lowercased().contains("오류") || trimmed.contains("원문") {
                inCorrectedBlock = false
                inTableBlock = true
                continue
            }
            if trimmed.hasPrefix("|---") { continue }

            if inCorrectedBlock && !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                if corrected.isEmpty { corrected = trimmed }
            } else if inTableBlock && trimmed.hasPrefix("|") {
                let cols = trimmed.split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                if cols.count >= 3 {
                    let original = cols.indices.contains(1) ? cols[1] : ""
                    let fix = cols.indices.contains(2) ? cols[2] : ""
                    let reason = cols.indices.contains(3) ? cols[3] : ""
                    if !original.isEmpty && !original.lowercased().contains("원문") {
                        corrections.append(Correction(original: original, corrected: fix, reason: reason))
                    }
                }
            }
        }

        // fallback: if no structured parse, try to extract from plain text
        if corrected.isEmpty {
            for line in lines {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("→") || t.hasPrefix("✓") {
                    corrected = t.replacingOccurrences(of: "→", with: "").replacingOccurrences(of: "✓", with: "").trimmingCharacters(in: .whitespaces)
                    break
                }
            }
        }

        self.correctedText = corrected
        self.corrections = corrections
    }
}

#if DEBUG
#Preview {
    SpellCheckResultCardView(
        text: """
        교정 결과
        안녕하세요. 저는 오늘 회의에 참석했습니다.

        변경 항목
        | 원문 | 교정 | 이유 |
        |------|------|------|
        | 안녕하세여 | 안녕하세요 | 맞춤법 |
        | 참석했읍니다 | 참석했습니다 | 맞춤법 |
        """,
        isDarkMode: false
    )
    .padding()
}
#endif
