import Foundation

// MARK: - VoiceTuningValues
// Round 259TTS-VOICE-TUNER: P/R/S 임시 튜닝값 컨테이너.
//
// pitch: cents (AVAudioUnitTimePitch). UI 기본 범위 -180~+180.
//   ±100 초과 시 금속성/비프음 artifact 가능 — UI에 경고 표시.
//   AudioPlaybackService clamp(-300~+360)보다 좁게 설정.
// rate: 재생 후처리 배율. UI 범위 0.92~1.12.
// speed: Supertonic3 합성 duration predictor 속도 스케일. UI 범위 0.90~1.20.
//   캐릭터 말 빠르기 조정은 S(speed) 우선 사용.

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
    /// UI 슬라이더 범위. AudioPlaybackService 내부 clamp보다 보수적.
    static let pitchRange:  ClosedRange<Float> = -180...180
    static let rateRange:   ClosedRange<Float> = 0.92...1.12
    static let speedRange:  ClosedRange<Float> = 0.90...1.20

    /// Pitch artifact 경고 임계값.
    /// ±100 cents (약 1 semitone) 초과 시 일부 preset에서 금속성/비프음 artifact 가능.
    static let pitchArtifactThreshold: Float = 100.0

    static let pitchStep:  Double = 10.0
    static let rateStep:   Double = 0.01
    static let speedStep:  Double = 0.01
}
