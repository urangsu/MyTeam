import Foundation

// MARK: - KoreanTextMetrics

struct KoreanTextMetrics: Equatable {
    let originalText: String
    let charactersWithSpaces: Int
    let charactersWithoutWhitespace: Int
    let utf8Bytes: Int
    let koreanFormBytes: Int
    let lineCount: Int
    let paragraphCount: Int
}

// MARK: - KoreanTextMetricsService

enum KoreanTextMetricsService {

    /// 한국어 텍스트의 메트릭을 분석한다 (로컬 처리, 외부 API 호출 없음)
    static func analyze(_ text: String) -> KoreanTextMetrics {
        let charactersWithSpaces = text.count
        let charactersWithoutWhitespace = text.filter { !$0.isWhitespace }.count
        let utf8Bytes = text.data(using: .utf8)?.count ?? 0
        let koreanFormBytes = calculateKoreanFormBytes(text)
        let lineCount = calculateLineCount(text)
        let paragraphCount = calculateParagraphCount(text)

        return KoreanTextMetrics(
            originalText: text,
            charactersWithSpaces: charactersWithSpaces,
            charactersWithoutWhitespace: charactersWithoutWhitespace,
            utf8Bytes: utf8Bytes,
            koreanFormBytes: koreanFormBytes,
            lineCount: lineCount,
            paragraphCount: paragraphCount
        )
    }

    /// 사용자 메시지에서 계산 대상 텍스트를 추출한다
    /// - 콜론 뒤의 텍스트 추출
    /// - 첫 줄이 명령이면 나머지 추출
    /// - 따옴표로 감싼 텍스트 우선 추출
    /// - 본문이 없으면 nil 반환
    static func extractTargetText(from message: String) -> String? {
        let trimmed = message.trimmingCharacters(in: .whitespaces)

        // 1. 따옴표로 감싼 텍스트 찾기
        if let quoted = extractQuotedText(from: trimmed) {
            return quoted
        }

        // 2. 콜론 뒤의 텍스트
        if let colonIndex = trimmed.firstIndex(of: ":") {
            let afterColon = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            if !afterColon.isEmpty {
                return afterColon
            }
        }

        // 3. 첫 줄이 명령(명사+동사)이고 다음 줄부터 본문인 경우
        let lines = trimmed.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if lines.count > 1 {
            let firstLine = lines[0].lowercased()
            // 명령어 키워드 확인
            if firstLine.contains("글자") || firstLine.contains("바이트") || firstLine.contains("수") {
                let bodyLines = Array(lines.dropFirst()).joined(separator: "\n")
                let bodyTrimmed = bodyLines.trimmingCharacters(in: .whitespaces)
                if !bodyTrimmed.isEmpty {
                    return bodyTrimmed
                }
            }
        }

        // 본문 없음
        return nil
    }

    /// 분석 결과를 사용자 친화적으로 포맷한다
    static func formatResult(_ metrics: KoreanTextMetrics) -> String {
        return """
        한국어 글자 수 세기 · 로컬 처리

        공백 포함: \(metrics.charactersWithSpaces)자
        공백 제외: \(metrics.charactersWithoutWhitespace)자
        UTF-8: \(metrics.utf8Bytes) bytes
        한국 제출폼 기준: \(metrics.koreanFormBytes) bytes
        줄 수: \(metrics.lineCount)줄
        문단 수: \(metrics.paragraphCount)개

        기준:
        • UTF-8은 실제 파일/웹 전송 기준입니다.
        • 한국 제출폼 기준은 한글 2바이트, 영문/숫자 1바이트 근사값입니다.
        """
    }

    // MARK: - Private Helpers

    private static func calculateKoreanFormBytes(_ text: String) -> Int {
        var bytes = 0
        for scalar in text.unicodeScalars {
            if scalar.isASCII {
                bytes += 1
            } else {
                // 한국 제출폼 기준은 한글 2바이트, 영문/숫자 1바이트 근사값이다.
                bytes += 2
            }
        }
        return bytes
    }

    private static func calculateLineCount(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return text.components(separatedBy: .newlines).count
    }

    private static func calculateParagraphCount(_ text: String) -> Int {
        let lines = text.components(separatedBy: .newlines)
        var count = 0
        var isInsideParagraph = false
        for line in lines {
            let hasText = !line.trimmingCharacters(in: .whitespaces).isEmpty
            if hasText && !isInsideParagraph {
                count += 1
                isInsideParagraph = true
            } else if !hasText {
                isInsideParagraph = false
            }
        }
        return count
    }

    private static func extractQuotedText(from text: String) -> String? {
        // Array of quote pairs: (opening, closing) where some opening and closing are same
        let quotePairs = [
            ("\"", "\""),
            ("'", "'"),
            ("\u{201C}", "\u{201D}"),  // Left/right double quotation marks
            ("「", "」"),               // Japanese corner brackets
            ("『", "』")                // Japanese corner brackets
        ]

        for (openQuote, closeQuote) in quotePairs {
            if let start = text.range(of: openQuote) {
                let afterStart = text[start.upperBound...]
                if let endQuote = afterStart.range(of: closeQuote) {
                    let quoted = String(afterStart[..<endQuote.lowerBound])
                    if !quoted.isEmpty {
                        return quoted
                    }
                }
            }
        }
        return nil
    }
}
