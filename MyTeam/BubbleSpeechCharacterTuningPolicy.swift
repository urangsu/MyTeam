import Foundation

struct BubbleSpeechCharacterTuning: Sendable, Equatable {
    let minSegmentDuration: Double
    let maxSegmentDuration: Double
    let guideGain: Float
    let shimmerDepth: Float
    let gapScale: Double

    static let neutral = BubbleSpeechCharacterTuning(
        minSegmentDuration: 0.034,
        maxSegmentDuration: 0.066,
        guideGain: 0.075,
        shimmerDepth: 0.03,
        gapScale: 1.0
    )
}

enum BubbleSpeechCharacterTuningPolicy {
    static func tuning(
        agentID: String?,
        preset: String,
        profile: BubbleSpeechVoiceProfile
    ) -> BubbleSpeechCharacterTuning {
        let presetFamily = preset.first
        var tuning: BubbleSpeechCharacterTuning

        switch presetFamily {
        case "F":
            tuning = BubbleSpeechCharacterTuning(
                minSegmentDuration: 0.038,
                maxSegmentDuration: 0.070,
                guideGain: 0.058,
                shimmerDepth: 0.024,
                gapScale: 0.92
            )
        case "M":
            tuning = BubbleSpeechCharacterTuning(
                minSegmentDuration: 0.040,
                maxSegmentDuration: 0.074,
                guideGain: 0.052,
                shimmerDepth: 0.020,
                gapScale: 0.96
            )
        default:
            tuning = .neutral
        }

        if profile.isEffectProfile {
            tuning = BubbleSpeechCharacterTuning(
                minSegmentDuration: max(0.026, tuning.minSegmentDuration - 0.010),
                maxSegmentDuration: max(0.050, tuning.maxSegmentDuration - 0.012),
                guideGain: min(0.12, tuning.guideGain + 0.025),
                shimmerDepth: min(0.05, tuning.shimmerDepth + 0.018),
                gapScale: max(0.72, tuning.gapScale - 0.12)
            )
        } else if profile == .cute || profile == .tiny {
            tuning = BubbleSpeechCharacterTuning(
                minSegmentDuration: tuning.minSegmentDuration,
                maxSegmentDuration: tuning.maxSegmentDuration,
                guideGain: max(0.040, tuning.guideGain - 0.010),
                shimmerDepth: tuning.shimmerDepth,
                gapScale: tuning.gapScale
            )
        }

        switch agentID {
        case "agent_5": // Chiko: keep the voice present and playful, not synthetic-only.
            return BubbleSpeechCharacterTuning(
                minSegmentDuration: max(tuning.minSegmentDuration, 0.040),
                maxSegmentDuration: max(tuning.maxSegmentDuration, 0.070),
                guideGain: min(tuning.guideGain, 0.055),
                shimmerDepth: tuning.shimmerDepth,
                gapScale: tuning.gapScale
            )
        case "agent_4": // Pin: allow a quicker design-tool rhythm.
            return BubbleSpeechCharacterTuning(
                minSegmentDuration: max(0.032, tuning.minSegmentDuration - 0.004),
                maxSegmentDuration: max(0.060, tuning.maxSegmentDuration - 0.004),
                guideGain: tuning.guideGain,
                shimmerDepth: tuning.shimmerDepth,
                gapScale: max(0.82, tuning.gapScale - 0.04)
            )
        case "agent_1": // Leo: lower voice needs less guide and more presence.
            return BubbleSpeechCharacterTuning(
                minSegmentDuration: max(tuning.minSegmentDuration, 0.042),
                maxSegmentDuration: max(tuning.maxSegmentDuration, 0.074),
                guideGain: min(tuning.guideGain, 0.050),
                shimmerDepth: min(tuning.shimmerDepth, 0.022),
                gapScale: tuning.gapScale
            )
        default:
            return tuning
        }
    }
}
