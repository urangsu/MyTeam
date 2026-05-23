import Foundation

// MARK: - SupertonicEmotionStyle
// Round 258TTS-CHARACTER-VOICE-SYSTEM: Supertonic3 감정 발화 스타일.
//
// 각 캐릭터는 CharacterVoiceProfile.defaultEmotionStyle로 기본 스타일을 갖는다.
// SupertonicProsodyTextProcessor.preprocess에서 스타일에 따라 텍스트를 소프트 변환.

enum SupertonicEmotionStyle: String, Sendable, CaseIterable {
    case neutral       // 중립 — 수치/법률/보고서 등 정형 텍스트
    case friendly      // 친근 — 쉬운 문장, 부드러운 말투
    case confident     // 자신감 — 전략가, 개발자 톤
    case careful       // 신중 — 법률, QA, PM 톤
    case excited       // 신남 — 마케터, 디자이너 톤
    case animalCrossing // 강한 모드 — 미래 옵션, 기본 비활성
}

// MARK: - SupertonicProsodyTextProcessor
// Round 258TTS-CHARACTER-VOICE-SYSTEM: TTS 입력 텍스트 경량 전처리.
//
// 원칙:
//   - 말풍선 원문은 절대 변경하지 않음 — TTS 입력 텍스트만 처리.
//   - 의미 변경 금지. 오직 자연스러운 발화를 위한 형태만 변환.
//   - 법률/회계/금액/숫자가 많은 문장 → neutral 처리 (변환 스킵).
//   - 200자 초과 텍스트 → 첫 200자 + "..." 처리 (긴 보고서 읽기 방지).
//
// 1차 변환 규칙 (minimal):
//   - 개행 → 공백, 연속 공백 정리.
//   - style == .friendly && text.count < 80: 경어 소프트 변환.
//   - 쉼표 보완: "먼저 " → "먼저, ", "그럼 " → "그럼, ".

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

        // 1. 법률/회계/숫자 감지 → neutral 처리 (변환 스킵, tag도 금지)
        if looksLikeFormalOrNumericText(text) {
            return normalizeWhitespace(text, truncate: true)
        }

        // 2. animalCrossing 스타일 → 텍스트 변환 없음 (pitch/rate/speed로 처리)
        if effectiveStyle == .animalCrossing {
            var result = normalizeWhitespace(text, truncate: true)
            if useExpressionTags {
                result = SupertonicExpressionTagPolicy.apply(emotion: effectiveStyle, to: result)
            }
            return result
        }

        // 3. 기본 정규화
        var result = normalizeWhitespace(text, truncate: true)

        // 4. 쉼표 보완 (짧은 텍스트만)
        if result.count < 150 {
            result = addCommaBoosts(result)
        }

        // 5. 감정 스타일별 소프트 변환 (friendly, 짧은 텍스트만)
        if effectiveStyle == .friendly && result.count < 80 {
            result = applyFriendlyTransforms(result)
        }

        // 6. Expression tags (TTS Lab 테스트 전용)
        if useExpressionTags {
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

    // MARK: - Private: Whitespace Normalization

    private static func normalizeWhitespace(_ text: String, truncate: Bool) -> String {
        var result = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        if truncate && result.count > 200 {
            result = String(result.prefix(200)) + "..."
        }

        return result
    }

    // MARK: - Private: Comma Boosts

    private static func addCommaBoosts(_ text: String) -> String {
        var result = text
        // "먼저 " → "먼저, " (연결어 앞 쉼표 추가)
        let connectors = ["먼저", "그럼", "그러면", "그리고", "하지만", "그래서", "따라서", "우선"]
        for connector in connectors {
            let pattern = connector + " "
            let replacement = connector + ", "
            // 이미 쉼표가 있으면 스킵
            if !result.contains(connector + ",") {
                result = result.replacingOccurrences(of: pattern, with: replacement)
            }
        }
        return result
    }

    // MARK: - Private: Friendly Style Transforms

    private static func applyFriendlyTransforms(_ text: String) -> String {
        var result = text
        // 딱딱한 공식 표현 → 부드러운 표현
        let transforms: [(String, String)] = [
            ("하겠습니다.", "해볼게요."),
            ("하겠습니다!", "해볼게요!"),
            ("확인했습니다.", "확인했어요."),
            ("완료했습니다.", "완료했어요."),
            ("시작하겠습니다.", "시작할게요."),
            ("진행하겠습니다.", "진행할게요."),
        ]
        for (from, to) in transforms {
            result = result.replacingOccurrences(of: from, with: to)
        }
        return result
    }
}
