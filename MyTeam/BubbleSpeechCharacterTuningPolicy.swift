import Foundation

enum BubbleSpeechEffectStrength: String, Sendable, Equatable {
    case bypass
    case light
    case medium
    case strong
}

struct BubbleSpeechEffectDecision: Sendable, Equatable {
    let strength: BubbleSpeechEffectStrength
    let wetMix: Float
    let targetSyllableDuration: ClosedRange<Double>
    let reason: String
}

enum BubbleSpeechEffectPolicy {
    static func decision(for text: String, requested: Bool) -> BubbleSpeechEffectDecision {
        guard requested else { return bypass(reason: "effectDisabled") }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return bypass(reason: "emptyText") }
        guard !containsStructuredContent(trimmed) else { return bypass(reason: "structuredContent") }

        let voicedCharacters = trimmed.filter { $0.isLetter || $0.isNumber }
        let count = voicedCharacters.count
        guard count > 0 else { return bypass(reason: "noVoicedCharacters") }
        guard count <= 180 else { return bypass(reason: "longBusinessText") }

        let numberCount = voicedCharacters.filter(\.isNumber).count
        let numericDensity = Double(numberCount) / Double(max(1, count))
        if numberCount >= 4 || numericDensity >= 0.18 || containsBusinessDataMarker(trimmed) {
            return BubbleSpeechEffectDecision(
                strength: .light,
                wetMix: 0.25,
                targetSyllableDuration: 0.060...0.090,
                reason: "dataReadability"
            )
        }

        if count <= 24 {
            return BubbleSpeechEffectDecision(
                strength: .strong,
                wetMix: 0.78,
                targetSyllableDuration: 0.042...0.068,
                reason: "shortCharacterLine"
            )
        }
        if count <= 80 {
            return BubbleSpeechEffectDecision(
                strength: .medium,
                wetMix: 0.58,
                targetSyllableDuration: 0.050...0.078,
                reason: "mediumDialogue"
            )
        }
        return BubbleSpeechEffectDecision(
            strength: .light,
            wetMix: 0.28,
            targetSyllableDuration: 0.058...0.088,
            reason: "longDialogue"
        )
    }

    private static func bypass(reason: String) -> BubbleSpeechEffectDecision {
        BubbleSpeechEffectDecision(
            strength: .bypass,
            wetMix: 0,
            targetSyllableDuration: 0...0,
            reason: reason
        )
    }

    private static func containsStructuredContent(_ text: String) -> Bool {
        text.contains("```") ||
        text.localizedCaseInsensitiveContains("https://") ||
        text.localizedCaseInsensitiveContains("http://") ||
        text.components(separatedBy: "\n").count >= 6
    }

    private static func containsBusinessDataMarker(_ text: String) -> Bool {
        ["원", "%", "₩", "$", "기준일", "사업연도", "조문"]
            .contains { text.contains($0) }
    }
}

struct BubbleSpeechCharacterTuning: Sendable, Equatable {
    let minSegmentDuration: Double
    let maxSegmentDuration: Double
    let guideGain: Float
    let shimmerDepth: Float
    let gapScale: Double
    let pitchStepPattern: [Double]
    let accentPattern: [Float]
    let grainRepeatPattern: [Int]
    let formantColor: Float

    init(
        minSegmentDuration: Double,
        maxSegmentDuration: Double,
        guideGain: Float,
        shimmerDepth: Float,
        gapScale: Double,
        pitchStepPattern: [Double] = [0, 8, -5],
        accentPattern: [Float] = [1.0, 0.92, 1.04],
        grainRepeatPattern: [Int] = [1, 1, 2],
        formantColor: Float = 0
    ) {
        self.minSegmentDuration = minSegmentDuration
        self.maxSegmentDuration = maxSegmentDuration
        self.guideGain = guideGain
        self.shimmerDepth = shimmerDepth
        self.gapScale = gapScale
        self.pitchStepPattern = pitchStepPattern
        self.accentPattern = accentPattern
        self.grainRepeatPattern = grainRepeatPattern
        self.formantColor = formantColor
    }

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
            tuning = BubbleSpeechCharacterTuning(
                minSegmentDuration: max(tuning.minSegmentDuration, 0.052),
                maxSegmentDuration: max(tuning.maxSegmentDuration, 0.090),
                guideGain: min(tuning.guideGain, 0.044),
                shimmerDepth: tuning.shimmerDepth,
                gapScale: max(tuning.gapScale, 1.10)
            )
        case "agent_4": // Pin: keep the rhythm crisp without outrunning the character voice.
            tuning = BubbleSpeechCharacterTuning(
                minSegmentDuration: max(0.044, tuning.minSegmentDuration - 0.002),
                maxSegmentDuration: max(0.080, tuning.maxSegmentDuration - 0.002),
                guideGain: tuning.guideGain,
                shimmerDepth: tuning.shimmerDepth,
                gapScale: max(1.02, tuning.gapScale - 0.01)
            )
        case "agent_1": // Leo: lower voice needs less guide and more presence.
            tuning = BubbleSpeechCharacterTuning(
                minSegmentDuration: max(tuning.minSegmentDuration, 0.056),
                maxSegmentDuration: max(tuning.maxSegmentDuration, 0.096),
                guideGain: min(tuning.guideGain, 0.036),
                shimmerDepth: min(tuning.shimmerDepth, 0.018),
                gapScale: max(tuning.gapScale, 1.14)
            )
        default:
            break
        }

        let identity = rhythmIdentity(for: agentID)
        return BubbleSpeechCharacterTuning(
            minSegmentDuration: tuning.minSegmentDuration,
            maxSegmentDuration: tuning.maxSegmentDuration,
            guideGain: tuning.guideGain,
            shimmerDepth: tuning.shimmerDepth,
            gapScale: tuning.gapScale,
            pitchStepPattern: identity.pitch,
            accentPattern: identity.accent,
            grainRepeatPattern: identity.repeatPattern,
            formantColor: identity.formant
        )
    }

    private static func rhythmIdentity(for agentID: String?) -> (
        pitch: [Double], accent: [Float], repeatPattern: [Int], formant: Float
    ) {
        switch agentID {
        case "agent_1": return ([-18, -6, -28], [1.08, 0.90, 1.00], [2, 1, 1], -0.22)
        case "agent_2": return ([18, 34, 8, 26], [1.00, 1.08, 0.92, 1.04], [1, 1, 2, 1], 0.18)
        case "agent_3": return ([2, 12, -4], [1.04, 0.94, 1.02], [1, 2, 1], -0.02)
        case "agent_4": return ([22, 4], [1.10, 0.88], [1, 1], 0.14)
        case "agent_5": return ([36, 10, 42, -2], [1.12, 0.86, 1.06, 0.94], [1, 2, 1, 2], 0.24)
        case "agent_6": return ([-30, -12, -38, -18], [1.02, 0.88, 1.06, 0.92], [2, 1, 2, 1], -0.28)
        case "agent_7": return ([-8, 6, -2, 14], [1.06, 0.90, 1.00, 0.94], [1, 1, 1, 2], -0.08)
        case "agent_8": return ([6, -10, 12], [0.96, 1.08, 0.90], [2, 1, 2], 0.04)
        case "agent_9": return ([14, 28, 2], [1.08, 0.96, 0.90], [1, 2, 2], 0.10)
        case "agent_10": return ([28, 12, 34], [1.04, 0.88, 1.10], [2, 2, 1], 0.20)
        case "agent_11": return ([-4, -18, 8, -10], [1.00, 1.06, 0.88, 1.02], [1, 2, 1, 1], -0.12)
        default: return ([0, 8, -5], [1.0, 0.92, 1.04], [1, 1, 2], 0)
        }
    }
}
