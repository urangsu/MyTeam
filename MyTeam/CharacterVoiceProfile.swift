import Foundation

// MARK: - CharacterVoiceProfile
// Round 258TTS-CHARACTER-VOICE-SYSTEM: 캐릭터별 TTS 목소리 정체성 정의.
//
// basePitch/baseRate: Supertonic 경로 기본 재생 값 (VoiceStyleCatalog 기존값 계승).
//   pitch 단위: cents (AVAudioUnitTimePitch.pitch). ±100 cents ≈ 1 semitone.
//   rate 단위: 배율 (1.0 = 원본). clamp 범위: rate 0.90~1.14.
// baseSpeed: Supertonic3ONNXRunner.synthesize(speed:) 값. duration predictor 스케일.
//   range: 0.85~1.25. 1.0 = 원래 속도. 1.05 = 현재 기본값.
// emotionPitchBoost / emotionRateBoost: 감정 발화 시 basePitch/baseRate에 더함.
// animalCrossingPitchBoost / animalCrossingRateBoost: 강한 모드 추가 boost (기본 OFF).
// defaultEmotionStyle: 캐릭터 기본 감정 스타일 (SupertonicProsodyTextProcessor 전처리에 사용).

struct CharacterVoiceProfile: Sendable, Identifiable {
    let id: String                       // e.g. "leo_m1"
    let agentID: String                  // "agent_1"
    let displayName: String              // "레오"
    let preset: String                   // "M1" (Supertonic3 voice preset)
    let basePitch: Float                 // cents (AVAudioUnitTimePitch)
    let baseRate: Float                  // 재생 배율 (1.0 기준)
    let baseSpeed: Float                 // Supertonic3 duration predictor 속도 스케일
    let emotionPitchBoost: Float         // 감정 발화 시 추가 pitch
    let emotionRateBoost: Float          // 감정 발화 시 추가 rate
    let animalCrossingPitchBoost: Float  // 강한 모드 추가 pitch (기본 미사용)
    let animalCrossingRateBoost: Float   // 강한 모드 추가 rate (기본 미사용)
    let defaultEmotionStyle: SupertonicEmotionStyle
    let styleNote: String                // "낮고 안정적인 전략가 톤"
    let sampleLine: String               // 샘플 발화 문장
}

// MARK: - CharacterVoiceProfileCatalog

enum CharacterVoiceProfileCatalog {

    // pitch/rate 값: VoiceStyleCatalog 기존값 계승 (cents 기준).
    // AnimalCrossing boost는 basePitch에 더해서 강한 모드를 만드는 추가 값.
    static let profiles: [CharacterVoiceProfile] = [
        CharacterVoiceProfile(
            id: "leo_m1",
            agentID: "agent_1",
            displayName: "레오",
            preset: "M1",
            basePitch: -180,
            baseRate: 0.94,
            baseSpeed: 1.00,
            emotionPitchBoost: -20,
            emotionRateBoost: -0.01,
            animalCrossingPitchBoost: -120,
            animalCrossingRateBoost: -0.03,
            defaultEmotionStyle: .confident,
            styleNote: "낮고 안정적인 전략가 톤",
            sampleLine: "핵심부터 정리해보겠습니다."
        ),
        CharacterVoiceProfile(
            id: "luna_f1",
            agentID: "agent_2",
            displayName: "루나",
            preset: "F1",
            basePitch: 180,
            baseRate: 1.03,
            baseSpeed: 1.05,
            emotionPitchBoost: 20,
            emotionRateBoost: 0.02,
            animalCrossingPitchBoost: 80,
            animalCrossingRateBoost: 0.02,
            defaultEmotionStyle: .excited,
            styleNote: "밝고 콘텐츠형 마케터 톤",
            sampleLine: "좋은 아이디어가 생각났어요!"
        ),
        CharacterVoiceProfile(
            id: "moco_f3",
            agentID: "agent_3",
            displayName: "모코",
            preset: "F3",
            basePitch: 90,
            baseRate: 0.97,
            baseSpeed: 1.00,
            emotionPitchBoost: 10,
            emotionRateBoost: 0.01,
            animalCrossingPitchBoost: 60,
            animalCrossingRateBoost: 0.02,
            defaultEmotionStyle: .careful,
            styleNote: "침착한 PM 톤",
            sampleLine: "일정을 확인해 드릴게요."
        ),
        CharacterVoiceProfile(
            id: "pin_f4",
            agentID: "agent_4",
            displayName: "핀",
            preset: "F4",
            basePitch: 320,
            baseRate: 1.10,
            baseSpeed: 1.08,
            emotionPitchBoost: 30,
            emotionRateBoost: 0.02,
            animalCrossingPitchBoost: 160,
            animalCrossingRateBoost: 0.06,
            defaultEmotionStyle: .friendly,
            styleNote: "경쾌한 디자이너 톤",
            sampleLine: "디자인 작업 시작할게요!"
        ),
        CharacterVoiceProfile(
            id: "chiko_f2",
            agentID: "agent_5",
            displayName: "치코",
            preset: "F2",
            basePitch: 260,
            baseRate: 1.08,
            baseSpeed: 1.05,
            emotionPitchBoost: 20,
            emotionRateBoost: 0.02,
            animalCrossingPitchBoost: 140,
            animalCrossingRateBoost: 0.05,
            defaultEmotionStyle: .friendly,
            styleNote: "친근한 온보딩 도우미 톤",
            sampleLine: "도와드릴게요, 함께 해봐요!"
        ),
        CharacterVoiceProfile(
            id: "rex_m3",
            agentID: "agent_6",
            displayName: "렉스",
            preset: "M3",
            basePitch: -260,
            baseRate: 0.92,
            baseSpeed: 0.95,
            emotionPitchBoost: -20,
            emotionRateBoost: -0.02,
            animalCrossingPitchBoost: -100,
            animalCrossingRateBoost: -0.03,
            defaultEmotionStyle: .careful,
            styleNote: "느리고 신중한 법률가 톤",
            sampleLine: "법적 사항을 검토하겠습니다."
        ),
        CharacterVoiceProfile(
            id: "kay_m2",
            agentID: "agent_7",
            displayName: "케이",
            preset: "M2",
            basePitch: -120,
            baseRate: 0.98,
            baseSpeed: 1.02,
            emotionPitchBoost: -15,
            emotionRateBoost: -0.01,
            animalCrossingPitchBoost: -80,
            animalCrossingRateBoost: -0.02,
            defaultEmotionStyle: .neutral,
            styleNote: "또렷한 분석가 톤",
            sampleLine: "데이터를 분석해 보겠습니다."
        ),
        CharacterVoiceProfile(
            id: "lacky_m4",
            agentID: "agent_8",
            displayName: "래키",
            preset: "M4",
            basePitch: 120,
            baseRate: 1.06,
            baseSpeed: 1.05,
            emotionPitchBoost: 15,
            emotionRateBoost: 0.02,
            animalCrossingPitchBoost: 60,
            animalCrossingRateBoost: 0.03,
            defaultEmotionStyle: .confident,
            styleNote: "빠른 개발자 톤",
            sampleLine: "코드 작성을 시작하겠습니다."
        ),
        CharacterVoiceProfile(
            id: "pola_f5",
            agentID: "agent_9",
            displayName: "폴라",
            preset: "F5",
            basePitch: -180,
            baseRate: 0.94,
            baseSpeed: 1.03,
            emotionPitchBoost: -20,
            emotionRateBoost: -0.01,
            animalCrossingPitchBoost: -100,
            animalCrossingRateBoost: -0.03,
            defaultEmotionStyle: .confident,
            styleNote: "설득력 있는 세일즈 톤",
            sampleLine: "좋은 제안이 있습니다."
        ),
        CharacterVoiceProfile(
            id: "mongmong_f3b",
            agentID: "agent_10",
            displayName: "몽몽",
            preset: "F3",
            basePitch: 340,
            baseRate: 1.12,
            baseSpeed: 1.00,
            emotionPitchBoost: 25,
            emotionRateBoost: 0.02,
            animalCrossingPitchBoost: 180,
            animalCrossingRateBoost: 0.07,
            defaultEmotionStyle: .friendly,
            styleNote: "따뜻하고 상냥한 고객 서비스 톤",
            sampleLine: "도움이 필요하시면 말씀해 주세요."
        ),
        CharacterVoiceProfile(
            id: "oliver_m5",
            agentID: "agent_11",
            displayName: "올리버",
            preset: "M5",
            basePitch: -80,
            baseRate: 0.96,
            baseSpeed: 0.98,
            emotionPitchBoost: -10,
            emotionRateBoost: -0.01,
            animalCrossingPitchBoost: -50,
            animalCrossingRateBoost: -0.02,
            defaultEmotionStyle: .careful,
            styleNote: "꼼꼼한 QA 엔지니어 톤",
            sampleLine: "꼼꼼하게 확인해 드리겠습니다."
        )
    ]

    // MARK: - Lookup

    /// Returns the voice profile for the given agentID.
    /// Falls back to 루나(F1) for unknown or nil agentID.
    static func profile(for agentID: String?) -> CharacterVoiceProfile {
        guard let id = agentID else { return profiles[1] } // 루나 F1 default
        return profiles.first(where: { $0.agentID == id }) ?? profiles[1]
    }

    /// Returns the first profile using the given Supertonic3 preset string, or nil if not found.
    static func profile(forPreset preset: String) -> CharacterVoiceProfile? {
        profiles.first(where: { $0.preset == preset })
    }
}
