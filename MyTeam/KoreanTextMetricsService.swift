import Foundation

struct KoreanTextMetrics: Equatable {
    let charactersWithSpaces: Int
    let charactersWithoutWhitespace: Int
    let utf8Bytes: Int
    let koreanFormBytes: Int
    let lineCount: Int
    let paragraphCount: Int
}

struct KoreanTextMetricsDisplayData: Equatable {
    let charactersWithSpaces: String
    let charactersWithoutWhitespace: String
    let utf8Bytes: String
    let koreanFormBytes: String
    let lineCount: String
    let paragraphCount: String
}

enum KoreanTextMetricsService {

    static func analyze(_ text: String) -> KoreanTextMetrics {
        let charactersWithSpaces = text.count
        let charactersWithoutWhitespace = text.filter { !$0.isWhitespace }.count
        let utf8Bytes = text.data(using: .utf8)?.count ?? 0
        let koreanFormBytes = calculateKoreanFormBytes(text)

        let lines = text.split(whereSeparator: \.isNewline)
        let lineCount = max(1, lines.count)

        let paragraphs = text
            .components(separatedBy: CharacterSet.newlines)
            .reduce(into: (count: 0, inParagraph: false)) { state, line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    state.inParagraph = false
                } else if !state.inParagraph {
                    state.count += 1
                    state.inParagraph = true
                }
            }
            .count

        return KoreanTextMetrics(
            charactersWithSpaces: charactersWithSpaces,
            charactersWithoutWhitespace: charactersWithoutWhitespace,
            utf8Bytes: utf8Bytes,
            koreanFormBytes: koreanFormBytes,
            lineCount: lineCount,
            paragraphCount: max(1, paragraphs)
        )
    }

    static func extractTargetText(from message: String) -> String? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let quoted = extractQuotedText(from: trimmed) {
            return quoted
        }

        let separators = [":", "："]
        for separator in separators {
            if let range = trimmed.range(of: separator) {
                let candidate = trimmed[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                if !candidate.isEmpty {
                    return candidate
                }
            }
        }

        let lines = trimmed.components(separatedBy: .newlines)
        if lines.count > 1 {
            let body = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return body.isEmpty ? nil : body
        }

        return nil
    }

    static func formatResult(_ metrics: KoreanTextMetrics) -> String {
        """
        한국어 글자 수 세기 · 로컬 처리

        공백 포함: \(metrics.charactersWithSpaces)자
        공백 제외: \(metrics.charactersWithoutWhitespace)자
        UTF-8: \(metrics.utf8Bytes) bytes
        제출폼 기준: \(metrics.koreanFormBytes) bytes
        줄 수: \(metrics.lineCount)줄
        문단 수: \(metrics.paragraphCount)개

        기준:
        제출폼 기준은 한글 2바이트, 영문/숫자 1바이트 근사값입니다.
        """
    }

    static func formatCompact(_ metrics: KoreanTextMetrics) -> String {
        """
        공백 포함: \(metrics.charactersWithSpaces)자
        공백 제외: \(metrics.charactersWithoutWhitespace)자
        UTF-8: \(metrics.utf8Bytes) bytes
        제출폼 기준: \(metrics.koreanFormBytes) bytes
        줄 수: \(metrics.lineCount)줄
        문단 수: \(metrics.paragraphCount)개
        """
    }

    static func parseResultText(_ text: String) -> KoreanTextMetricsDisplayData? {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.contains("공백 포함:"), normalized.contains("제출폼 기준:") else {
            return nil
        }

        func value(for label: String) -> String? {
            let pattern = "\(NSRegularExpression.escapedPattern(for: label))\\s*([^\\n]+)"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            let range = NSRange(normalized.startIndex..., in: normalized)
            guard let match = regex.firstMatch(in: normalized, range: range),
                  let valueRange = Range(match.range(at: 1), in: normalized) else {
                return nil
            }
            return String(normalized[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard
            let charactersWithSpaces = value(for: "공백 포함:"),
            let charactersWithoutWhitespace = value(for: "공백 제외:"),
            let utf8Bytes = value(for: "UTF-8:"),
            let koreanFormBytes = value(for: "제출폼 기준:"),
            let lineCount = value(for: "줄 수:"),
            let paragraphCount = value(for: "문단 수:")
        else {
            return nil
        }

        return KoreanTextMetricsDisplayData(
            charactersWithSpaces: charactersWithSpaces,
            charactersWithoutWhitespace: charactersWithoutWhitespace,
            utf8Bytes: utf8Bytes,
            koreanFormBytes: koreanFormBytes,
            lineCount: lineCount,
            paragraphCount: paragraphCount
        )
    }

    private static func extractQuotedText(from text: String) -> String? {
        let patterns = [
            "\"([^\"]+)\"",
            "“([^”]+)”",
            "‘([^’]+)’",
            "'([^']+)'"
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  let valueRange = Range(match.range(at: 1), in: text) else {
                continue
            }
            let candidate = String(text[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !candidate.isEmpty {
                return candidate
            }
        }

        return nil
    }

    private static func calculateKoreanFormBytes(_ text: String) -> Int {
        text.reduce(0) { partial, char in
            if char.isASCII {
                return partial + 1
            }
            // 한국 제출폼 기준은 한글 2바이트, 영문/숫자 1바이트 근사값이다.
            return partial + 2
        }
    }
}
