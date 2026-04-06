import Foundation

// ============================================================
// TextSanitizer.swift
// Chatterbox TTS용 텍스트 정제 (정규식 필터)
//
// 기능:
//   1. 이름 태그 제거 ([루나], 루나:, **루나** 등)
//   2. 마크다운 기호 제거 (*, #, _, ~, `)
//   3. 이모지 제거
//   4. 행동 지문 괄호 제거 ((웃으며) → "")
//   5. 다국어 지원 (한글, 영어, 일본어)
//
// 사용법:
//   let clean = TextSanitizer.sanitize("**루나**: 안녕! 🎉")
//   // Result: "안녕!"
// ============================================================

enum TextSanitizer {

    /// 텍스트를 TTS에 최적화된 형태로 정제
    static func sanitize(_ rawText: String) -> String {
        var text = rawText

        // 1단계: 이름 태그 제거
        // 패턴: [이름], **이름**:, 이름 -,  이름: 등
        text = removeNameTags(text)

        // 2단계: 마크다운 기호 제거 (*, #, _, ~, `)
        text = text.replacingOccurrences(of: "[*#_~`]", with: "", options: .regularExpression)

        // 3단계: 이모지 제거
        text = removeEmojis(text)

        // 4단계: 행동 지문 괄호 제거 ((웃으며), (한숨) 등)
        text = text.replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)

        // 5단계: 연속 공백 정리
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        // 6단계: 앞뒤 공백 제거
        text = text.trimmingCharacters(in: .whitespaces)

        return text
    }

    // MARK: - 이름 태그 제거
    /// [레오], **루나**:, 치코 -, 켄 ： 등 다양한 형식의 이름 태그 제거
    private static func removeNameTags(_ text: String) -> String {
        // 다국어 문자 인식 범위: 한글, 영어, 일본어 3자 이상 15자 이하
        let pattern = """
        ^\\s*
        (?:\\*\\*|\\*)?              # ** 또는 * 선택사항
        (?:\\[)?                     # [ 선택사항
        ([\\p{L}\\p{M}0-9]{1,15})   # 문자/숫자 1~15자
        (?:\\])?                     # ] 선택사항
        (?:\\*\\*|\\*)?              # ** 또는 * 선택사항
        \\s*[:：\\-]\\s*             # :, ：, - 등 구분자
        """
        return text.replacingOccurrences(
            of: pattern,
            with: "",
            options: .regularExpression
        )
    }

    // MARK: - 이모지 제거
    /// Unicode Emoji 범위 제거
    private static func removeEmojis(_ text: String) -> String {
        // Emoji 범위:
        // - 1F300-1F9FF: Emoticons, Symbols, Pictographs
        // - 1F600-1F64F: Emoticons
        // - 2600-27BF: Miscellaneous Symbols
        // - 1F900-1F9FF: Supplemental Symbols and Pictographs
        let pattern = "[\\p{Emoji}\\p{Emoji_Component}]"
        return text.replacingOccurrences(
            of: pattern,
            with: "",
            options: .regularExpression
        )
    }

    /// 텍스트가 비어있지 않은지 확인 (정제 후)
    static func isSafeForTTS(_ text: String) -> Bool {
        let cleaned = sanitize(text)
        return !cleaned.isEmpty && cleaned.count > 0
    }

    /// 텍스트 길이 제한 (Chatterbox 최대 입력 길이)
    static func truncate(_ text: String, maxLength: Int = 500) -> String {
        let cleaned = sanitize(text)
        guard cleaned.count > maxLength else { return cleaned }
        return String(cleaned.prefix(maxLength)) + "..."
    }
}
