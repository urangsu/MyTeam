import Foundation

struct BubbleSpeechCharacterTuning: Sendable, Equatable {
    let minSegmentDuration: Double
    let maxSegmentDuration: Double
    let guideGain: Float
    let shimmerDepth: Float
    let gapScale: Double

    static let neutral = BubbleSpeechCharacterTuning(
        minSegmentDuration: 0.046,
        maxSegmentDuration: 0.084,
        guideGain: 0.055,
        shimmerDepth: 0.022,
        gapScale: 1.08
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
                minSegmentDuration: 0.048,
                maxSegmentDuration: 0.086,
                guideGain: 0.044,
                shimmerDepth: 0.018,
                gapScale: 1.08
            )
        case "M":
            tuning = BubbleSpeechCharacterTuning(
                minSegmentDuration: 0.052,
                maxSegmentDuration: 0.092,
                guideGain: 0.038,
                shimmerDepth: 0.016,
                gapScale: 1.12
            )
        default:
            tuning = .neutral
        }

        if profile.isEffectProfile {
            tuning = BubbleSpeechCharacterTuning(
                minSegmentDuration: max(0.040, tuning.minSegmentDuration - 0.004),
                maxSegmentDuration: max(0.074, tuning.maxSegmentDuration - 0.006),
                guideGain: min(0.075, tuning.guideGain + 0.012),
                shimmerDepth: min(0.034, tuning.shimmerDepth + 0.010),
                gapScale: max(0.98, tuning.gapScale - 0.03)
            )
        } else if profile == .cute || profile == .tiny {
            tuning = BubbleSpeechCharacterTuning(
                minSegmentDuration: tuning.minSegmentDuration,
                maxSegmentDuration: tuning.maxSegmentDuration,
                guideGain: max(0.030, tuning.guideGain - 0.012),
                shimmerDepth: tuning.shimmerDepth,
                gapScale: tuning.gapScale + 0.04
            )
        }

        switch agentID {
        case "agent_5": // Chiko: keep the voice present and playful, not synthetic-only.
            return BubbleSpeechCharacterTuning(
                minSegmentDuration: max(tuning.minSegmentDuration, 0.052),
                maxSegmentDuration: max(tuning.maxSegmentDuration, 0.090),
                guideGain: min(tuning.guideGain, 0.044),
                shimmerDepth: tuning.shimmerDepth,
                gapScale: max(tuning.gapScale, 1.10)
            )
        case "agent_4": // Pin: keep the rhythm crisp without outrunning the character voice.
            return BubbleSpeechCharacterTuning(
                minSegmentDuration: max(0.044, tuning.minSegmentDuration - 0.002),
                maxSegmentDuration: max(0.080, tuning.maxSegmentDuration - 0.002),
                guideGain: tuning.guideGain,
                shimmerDepth: tuning.shimmerDepth,
                gapScale: max(1.02, tuning.gapScale - 0.01)
            )
        case "agent_1": // Leo: lower voice needs less guide and more presence.
            return BubbleSpeechCharacterTuning(
                minSegmentDuration: max(tuning.minSegmentDuration, 0.056),
                maxSegmentDuration: max(tuning.maxSegmentDuration, 0.096),
                guideGain: min(tuning.guideGain, 0.036),
                shimmerDepth: min(tuning.shimmerDepth, 0.018),
                gapScale: max(tuning.gapScale, 1.14)
            )
        default:
            return tuning
        }
    }
}
