import Foundation

// MARK: - SupertonicEmotionStyle
// Round 258TTS-CHARACTER-VOICE-SYSTEM: Supertonic3 감정 발화 스타일.
//
// 각 캐릭터는 CharacterVoiceProfile.defaultEmotionStyle로 기본 스타일을 갖는다.
// SupertonicProsodyTextProcessor.preprocess는 제품 발화에서 문구를 바꾸지 않는다.

enum SupertonicEmotionStyle: String, Sendable, CaseIterable {
    case neutral       // 중립 — 수치/법률/보고서 등 정형 텍스트
    case friendly      // 친근 — 쉬운 문장, 부드러운 말투
    case confident     // 자신감 — 전략가, 개발자 톤
    case careful       // 신중 — 법률, QA, PM 톤
    case excited       // 신남 — 마케터, 디자이너 톤
    case bubbleSpeech // 강한 모드 — 미래 옵션, 기본 비활성
}

// MARK: - SupertonicProsodyTextProcessor
// Round 258TTS-CHARACTER-VOICE-SYSTEM: TTS 입력 텍스트 경량 전처리.
//
// 원칙:
//   - 말풍선 원문과 TTS 발화 문구는 일치해야 함.
//   - 의미/어미/문장부호를 rewrite하지 않음. 말투는 pitch/rate/speed/BubbleSpeech 레이어에서 처리.
//   - 법률/회계/금액/숫자가 많은 문장 → neutral 처리 (변환 스킵).
//
// 제품 발화 변환 규칙:
//   - 기본 제품 발화는 원문을 그대로 전달.
//   - "하겠습니다" → "해볼게요" 같은 텍스트 rewrite 금지.
//   - 쉼표 삽입 같은 문장부호 rewrite 금지.

enum SupertonicProsodyTextProcessor {

    // MARK: - Public

    /// TTS 입력 텍스트를 감정 스타일에 맞게 전처리.
    /// - Parameters:
    ///   - text: 원본 텍스트 (말풍선 원문과 동일)
    ///   - agentID: 캐릭터 agentID (nil → friendly 기본 스타일)
    ///   - style: 감정 스타일 (nil → CharacterVoiceProfile.defaultEmotionStyle 사용)
    ///   - useExpressionTags: true 시 Supertonic3 expression tag 삽입 (기본 false).
    ///     TTS Lab 감정 테스트 전용. 기본 발화(speakOnce 등)에는 사용하지 않음.
    /// - Returns: TTS 입력용 전처리된 텍스트 (원본은 변경되지 않음)
    static func preprocess(
        _ text: String,
        agentID: String? = nil,
        style: SupertonicEmotionStyle? = nil,
        useExpressionTags: Bool = false
    ) -> String {
        let profile = CharacterVoiceProfileCatalog.profile(for: agentID)
        let effectiveStyle = style ?? profile.defaultEmotionStyle

        // Product speech must preserve the visible bubble wording.
        // Character style belongs in audio parameters/effects, not text rewrites.
        guard useExpressionTags else { return text }

        var result = text
        if useExpressionTags && !looksLikeFormalOrNumericText(result) {
            result = SupertonicExpressionTagPolicy.apply(emotion: effectiveStyle, to: result)
        }
        return result
    }

    // MARK: - Private: Formal/Numeric Detection

    /// 법률/회계/금액/숫자 중심 문장인지 판단.
    /// true → neutral 처리 (변환 스킵)
    private static func looksLikeFormalOrNumericText(_ text: String) -> Bool {
        // 숫자 밀도: 텍스트의 20% 이상이 숫자/특수기호이면 neutral
        let totalCount = text.count
        guard totalCount > 0 else { return false }

        let digitCount = text.unicodeScalars.filter { scalar in
            CharacterSet.decimalDigits.contains(scalar) || "₩$%,.:원만억천".unicodeScalars.contains(scalar)
        }.count
        if Double(digitCount) / Double(totalCount) > 0.20 { return true }

        // 법률/회계 키워드 포함 시 neutral
        let formalKeywords = ["조항", "법률", "계약", "규정", "조례", "세금", "부가세", "VAT", "매출", "영업이익",
                              "손익계산서", "재무", "회계", "감사", "법인", "주식", "배당", "이자율",
                              "약관", "동의서", "이용약관", "개인정보처리방침"]
        for keyword in formalKeywords {
            if text.contains(keyword) { return true }
        }

        return false
    }

}
