import Foundation

// ============================================================
// CharacterVoiceConfig.swift
// Chatterbox TTS 캐릭터별 감정 파라미터 설정
//
// 감정 상태 → exaggeration + cfg_weight 매핑
//
// 파라미터 설명:
//   - exaggeration: 감정 과장도 (0.0~1.0, 높을수록 감정 살앙)
//   - cfg_weight: 생성 지침 가중치 (0.0~1.0, 낮을수록 창의적/빠름)
// ============================================================

enum CharacterVoiceConfig {

    // MARK: - 캐릭터 13명

    static let allCharacters = [
        "레오", "루나", "치코", "렉스", "케이",
        "래키", "모코", "핀", "폴라", "몽몽",
        "올리버", "서비", "피터"
    ]

    // MARK: - 감정 상태별 Chatterbox 파라미터

    struct EmotionConfig {
        let exaggeration: Float    // 감정 과장도 (0.2~1.0)
        let cfg_weight: Float      // 생성 가중치 (0.3~0.7)
    }

    /// 감정 상태 → TTS 파라미터 매핑
    static func emotionConfig(for emotion: AnimationState) -> EmotionConfig {
        switch emotion {
        case .joy, .agree, .greeting:
            // 밝고 활발한 감정: 감정 극대화, 빠른 템포
            return EmotionConfig(exaggeration: 0.8, cfg_weight: 0.3)

        case .sad:
            // 슬픈 감정: 차분하고 느린 템포
            return EmotionConfig(exaggeration: 0.2, cfg_weight: 0.6)

        case .angry, .confused:
            // 화난 감정: 강렬하고 빠른 템포
            return EmotionConfig(exaggeration: 0.7, cfg_weight: 0.4)

        case .typing, .idle, .idleLoop, .resting:
            // 일반적인 상태: 자연스러운 톤
            return EmotionConfig(exaggeration: 0.5, cfg_weight: 0.5)

        case .speaking:
            // 말하는 중: 자연스러운 음성
            return EmotionConfig(exaggeration: 0.5, cfg_weight: 0.5)

        case .drag, .lifted, .dropped, .lowering, .landing, .backToWork, .clockIn:
            // 동작 중: 감정 표현 최소화
            return EmotionConfig(exaggeration: 0.3, cfg_weight: 0.6)

        case .look, .returnToTyping:
            // 기타 동작: 중간 정도
            return EmotionConfig(exaggeration: 0.5, cfg_weight: 0.5)

        case .disagree, .thinking, .praise, .sleeping, .clockOut, .lookLeft, .lookRight:
            // 폴백 상태들: 기본값 사용
            return EmotionConfig(exaggeration: 0.5, cfg_weight: 0.5)
        }
    }

    // MARK: - 캐릭터별 음성 특성 (선택사항)

    /// 캐릭터별 기본 음성 톤 조정
    /// (Chatterbox가 10초 샘플로 이미 캐릭터 스타일을 학습했으므로
    ///  추가 조정은 미미. 극적 효과용.)
    struct CharacterVoiceTrait {
        let characterID: String
        let voiceType: String        // ElevenLabs 목소리 유형
        let pitchOffset: Float       // 피치 미세조정 (-0.5 ~ 0.5)
        let speedOffset: Float       // 속도 미세조정 (-0.2 ~ 0.2)
    }

    static let characterTraits: [String: CharacterVoiceTrait] = [
        // 여성 밝고 활발
        "치코": CharacterVoiceTrait(characterID: "chiko", voiceType: "bright_female", pitchOffset: 0.15, speedOffset: 0.1),
        "루나": CharacterVoiceTrait(characterID: "luna", voiceType: "bright_female", pitchOffset: 0.1, speedOffset: 0.05),
        "몽몽": CharacterVoiceTrait(characterID: "mongmong", voiceType: "bright_female", pitchOffset: 0.2, speedOffset: 0.12),

        // 남성 낮고 차분
        "레오": CharacterVoiceTrait(characterID: "leo", voiceType: "deep_male", pitchOffset: -0.1, speedOffset: -0.05),
        "렉스": CharacterVoiceTrait(characterID: "rex", voiceType: "deep_male", pitchOffset: -0.15, speedOffset: -0.1),
        "올리버": CharacterVoiceTrait(characterID: "oliver", voiceType: "deep_male", pitchOffset: -0.05, speedOffset: -0.02),

        // 남성 중성적, 차분
        "케이": CharacterVoiceTrait(characterID: "kai", voiceType: "neutral_male", pitchOffset: 0.0, speedOffset: 0.0),
        "모코": CharacterVoiceTrait(characterID: "moko", voiceType: "neutral_male", pitchOffset: 0.05, speedOffset: 0.02),

        // 여성 활기찬
        "핀": CharacterVoiceTrait(characterID: "pin", voiceType: "energetic_female", pitchOffset: 0.1, speedOffset: 0.08),
        "폴라": CharacterVoiceTrait(characterID: "pola", voiceType: "energetic_female", pitchOffset: 0.12, speedOffset: 0.1),

        // 남성 편안한
        "래키": CharacterVoiceTrait(characterID: "lucky", voiceType: "casual_male", pitchOffset: 0.0, speedOffset: 0.05),

        // 추가 역할
        "서비": CharacterVoiceTrait(characterID: "servi", voiceType: "neutral_male", pitchOffset: 0.03, speedOffset: 0.02),
        "피터": CharacterVoiceTrait(characterID: "peter", voiceType: "deep_male", pitchOffset: -0.08, speedOffset: -0.03),
    ]

    /// 캐릭터의 음성 특성 조회
    static func voiceTrait(for characterName: String) -> CharacterVoiceTrait? {
        return characterTraits[characterName]
    }

    // MARK: - 다국어 지원

    /// 텍스트에서 감지된 언어별 TTS 설정
    enum LanguagePreference {
        case korean   // 한글
        case english  // English
        case japanese // 日本語
        case mixed    // 혼합

        var displayName: String {
            switch self {
            case .korean: return "한국어"
            case .english: return "English"
            case .japanese: return "日本語"
            case .mixed: return "Mixed"
            }
        }
    }

    /// 텍스트에서 주 언어 감지
    static func detectLanguage(_ text: String) -> LanguagePreference {
        var hasKorean = false
        var hasEnglish = false
        var hasJapanese = false

        for scalar in text.unicodeScalars {
            let v = scalar.value
            // 한글
            if (v >= 0xAC00 && v <= 0xD7A3) || (v >= 0x1100 && v <= 0x11FF) {
                hasKorean = true
            }
            // 일본어
            if (v >= 0x3040 && v <= 0x30FF) || (v >= 0x4E00 && v <= 0x9FFF) {
                hasJapanese = true
            }
            // 영어
            if (v >= 0x41 && v <= 0x5A) || (v >= 0x61 && v <= 0x7A) {
                hasEnglish = true
            }
        }

        let langCount = [hasKorean, hasEnglish, hasJapanese].filter { $0 }.count
        if langCount > 1 { return .mixed }
        if hasKorean { return .korean }
        if hasEnglish { return .english }
        if hasJapanese { return .japanese }
        return .korean // 기본값
    }
}
