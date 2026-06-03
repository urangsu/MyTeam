import Foundation

// MARK: - VoiceTuningValues
// Round 259TTS: P/R/S 임시 튜닝값 컨테이너.
// Round 260B: speed 범위 공식 0.70~2.00으로 확장.
//
// pitch: cents (AVAudioUnitTimePitch). UI 기본 범위 -180~+180.
//   ±100 초과 시 금속성/비프음 artifact 가능 — UI에 경고 표시.
//   AudioPlaybackService clamp(-300~+360)보다 좁게 설정.
// rate: 재생 후처리 배율. UI 범위 0.92~1.12.
// speed: Supertonic3 합성 duration predictor 속도 스케일.
//   Official Supertonic3 Python example documents speed 0.7 (slow) ~ 2.0 (fast).
//   MyTeam exposes the full official range for testing.
//   Recommended character tuning: 0.90~1.30.
//   1.30~1.60: experimental zone. 1.60~2.00: extreme/special-effect territory.

struct VoiceTuningValues: Codable, Sendable, Equatable {
    var pitch: Float
    var rate: Float
    var speed: Float

    /// 중립 기본값: pitch=0, rate=1.0, speed=1.05
    static let neutral = VoiceTuningValues(pitch: 0, rate: 1.0, speed: 1.05)

    /// UI 범위 내로 클램프된 값 반환.
    var clamped: VoiceTuningValues {
        VoiceTuningValues(
            pitch: min(VoiceTuningDefaults.pitchRange.upperBound,
                       max(VoiceTuningDefaults.pitchRange.lowerBound, pitch)),
            rate:  min(VoiceTuningDefaults.rateRange.upperBound,
                       max(VoiceTuningDefaults.rateRange.lowerBound, rate)),
            speed: min(VoiceTuningDefaults.speedRange.upperBound,
                       max(VoiceTuningDefaults.speedRange.lowerBound, speed))
        )
    }

    /// 표시용 문자열: "P +80 / R 1.04 / S 1.08"
    var displayString: String {
        String(format: "P %+.0f / R %.2f / S %.2f", pitch, rate, speed)
    }
}

// MARK: - VoiceTuningDefaults

enum VoiceTuningDefaults {
    /// UI 슬라이더 전체 범위.
    static let pitchRange:  ClosedRange<Float> = -180...180
    static let rateRange:   ClosedRange<Float> = 0.92...1.12

    // MARK: Speed ranges (Round 260B — official Supertonic3 0.70~2.00)
    /// Full official range per Supertonic3 Python examples: 0.7 slow ~ 2.0 fast.
    static let speedRange:  ClosedRange<Float> = 0.70...2.00

    /// 일반 캐릭터 음성 권장 범위. 이 범위에서 자연스러운 발화가 보장됨.
    static let recommendedSpeedRange: ClosedRange<Float>  = 0.90...1.30

    /// 실험적 범위. 약간 과장된 빠르기 — 표현력 있지만 부자연스러울 수 있음.
    static let experimentalSpeedRange: ClosedRange<Float> = 1.30...1.60

    /// 극단 범위. Animal Crossing / 장난감 효과 / 특수 실험 전용.
    /// 일반 캐릭터 음성에는 권장하지 않음.
    static let extremeSpeedRange: ClosedRange<Float>      = 1.60...2.00

    // MARK: Warning thresholds
    /// 이 값 미만 → 말이 늘어지고 발음이 흐려질 수 있음
    static let speedWarningLow: Float  = 0.80
    /// 이 값 초과 → 감정표현보다 효과음 느낌이 강해질 수 있음
    static let speedWarningHigh: Float = 1.30
    /// 이 값 초과 → 공식 범위 내 실험값이지만 일반 캐릭터에 권장하지 않음
    static let speedExtremeHigh: Float = 1.60

    /// Pitch artifact 경고 임계값.
    /// ±100 cents 초과 시 일부 preset에서 금속성/비프음 artifact 가능.
    static let pitchArtifactThreshold: Float = 100.0

    static let pitchStep:  Double = 10.0
    static let rateStep:   Double = 0.01
    static let speedStep:  Double = 0.05
}
