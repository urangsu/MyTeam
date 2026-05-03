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
    /// 알려진 에이전트 이름([레오], 레오:, **루나**: 등)만 제거.
    /// 일반 문장("좋아: 그렇게", "안녕하세요 수석님")은 보존.
    private static func removeNameTags(_ text: String) -> String {
        let knownNames = Set(agentPersonas.values.map { $0.name })

        // 패턴 1: [이름] 대괄호 형식 — 구분자 없어도 제거 ([레오] 좋습니다 → 좋습니다)
        let bracketPattern = "^\\s*\\[([\\p{L}\\p{M}0-9]{1,15})\\]\\s*(?:[:：\\-]\\s*)?"
        if let regex = try? NSRegularExpression(pattern: bracketPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let nameRange = Range(match.range(at: 1), in: text),
           knownNames.contains(String(text[nameRange])),
           let fullRange = Range(match.range, in: text) {
            return String(text[fullRange.upperBound...])
        }

        // 패턴 2: **이름**: / 이름: / 이름 - 등 — 구분자 필수 (레오: 좋습니다 → 좋습니다)
        let delimPattern = "^\\s*(?:\\*\\*|\\*)?([\\p{L}\\p{M}0-9]{1,15})(?:\\*\\*|\\*)?\\s*[:：\\-]\\s*"
        if let regex = try? NSRegularExpression(pattern: delimPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let nameRange = Range(match.range(at: 1), in: text),
           knownNames.contains(String(text[nameRange])),
           let fullRange = Range(match.range, in: text) {
            return String(text[fullRange.upperBound...])
        }

        return text
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
