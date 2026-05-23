import Foundation

// MARK: - SupertonicExpressionTag
// Round 260B-TTS-OFFICIAL-SPEED-RANGE: Supertonic3 expression tag 정책.
//
// Supertonic3 공식 문서(GitHub/Hugging Face) 예시 태그:
//   <laugh>, <breath>, <sigh>
//
// 정책:
//   - 기본 발화(speakOnce, dispatchToInferencePipeline)에는 자동 적용하지 않음.
//   - TTS Lab 감정 테스트에서 ON/OFF A/B 테스트로만 사용.
//   - 법률/회계/숫자 문장에는 tag 적용 금지 (SupertonicProsodyTextProcessor guard 사용).
//   - 태그가 글자로 읽히면(TTS 입력 오인식) 해당 태그는 비활성화 가능.
//   - 말풍선 원문에는 절대 표시하지 않음 — TTS 입력 텍스트에만 삽입.

enum SupertonicExpressionTag: String, CaseIterable, Sendable {
    case laugh  = "<laugh>"
    case breath = "<breath>"
    case sigh   = "<sigh>"

    var displayName: String {
        switch self {
        case .laugh:  return "laugh — 웃음/발랄"
        case .breath: return "breath — 숨결/부드러움"
        case .sigh:   return "sigh — 한숨/신중"
        }
    }

    /// 권장 감정 스타일 매핑.
    /// 기본 전략: pitch보다 speed + 문장 리듬 + 작은 tag로 감정 차별화.
    static func recommended(for emotion: SupertonicEmotionStyle) -> [SupertonicExpressionTag] {
        switch emotion {
        case .neutral:        return []
        case .friendly:       return [.breath]
        case .confident:      return []
        case .careful:        return [.breath]
        case .excited:        return [.laugh]
        case .animalCrossing: return [.laugh]
        }
    }
}

// MARK: - SupertonicExpressionTagPolicy

enum SupertonicExpressionTagPolicy {

    /// Tag를 텍스트 앞에 삽입하여 TTS 입력 문자열 반환.
    /// - Parameters:
    ///   - text: 원본 텍스트 (이미 prosody 전처리 완료된 것)
    ///   - tags: 삽입할 태그 목록
    /// - Returns: 태그가 접두사로 붙은 TTS 입력 문자열
    static func apply(tags: [SupertonicExpressionTag], to text: String) -> String {
        guard !tags.isEmpty else { return text }
        let prefix = tags.map(\.rawValue).joined()
        return prefix + text
    }

    /// 감정 스타일에 맞는 태그를 text에 자동 삽입.
    /// formal/numeric 텍스트면 tag 없이 원본 반환.
    static func apply(emotion: SupertonicEmotionStyle, to text: String) -> String {
        // formal/numeric 텍스트에는 tag 적용 금지
        guard !isFormalOrNumeric(text) else { return text }
        let tags = SupertonicExpressionTag.recommended(for: emotion)
        return apply(tags: tags, to: text)
    }

    // MARK: - Private

    private static func isFormalOrNumeric(_ text: String) -> Bool {
        let totalCount = text.count
        guard totalCount > 0 else { return false }
        let digitCount = text.unicodeScalars.filter { scalar in
            CharacterSet.decimalDigits.contains(scalar)
        }.count
        if Double(digitCount) / Double(totalCount) > 0.15 { return true }
        let formalKeywords = ["조항", "법률", "계약", "규정", "세금", "부가세", "VAT", "회계", "감사", "약관"]
        for keyword in formalKeywords where text.contains(keyword) {
            return true
        }
        return false
    }
}
