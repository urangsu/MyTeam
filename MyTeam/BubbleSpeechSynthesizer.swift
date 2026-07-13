import Foundation

// MARK: - BubbleSpeechSynthesizer
// Round 263TTS-BUBBLESPEECH-SINGLE-PASS-CHOPPER
//
// BubbleSpeech is MyTeam's own procedural syllable speech effect. It cuts a
// single Supertonic3 voice render into short syllable rhythm chunks, then adds
// a quiet procedural guide as attack/color support.
//
// Rules:
//   - No third-party original samples.
//   - No YouTube audio extraction.
//   - No external sample files.
//   - Pure procedural synthesis only.
//   - Optional character effect over one Supertonic3 render, never a fallback TTS.
//   - Guide generation failure is a BubbleSpeech failure, not passthrough success.

// MARK: - Wave / Profile

enum BubbleSpeechWaveform: String, CaseIterable, Sendable {
    case sine
    case triangle
    case squareSoft
    case noiseBlend

    var displayName: String {
        switch self {
        case .sine:       return "Sine"
        case .triangle:   return "Triangle"
        case .squareSoft: return "Square soft"
        case .noiseBlend: return "Noise blend"
        }
    }
}

enum BubbleSpeechVoiceProfile: String, CaseIterable, Sendable, Identifiable {
    case cute
    case calm
    case deep
    case tiny
    case robot
    case arcade

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cute:   return "맑은 뽀글"
        case .calm:   return "차분한 뽀글"
        case .deep:   return "낮은 뽀글"
        case .tiny:   return "작은 뽀글"
        case .robot:  return "로봇 뽀글"
        case .arcade: return "빠른 뽀글"
        }
    }

    var isEffectProfile: Bool {
        switch self {
        case .robot, .arcade: return true
        case .cute, .calm, .deep, .tiny: return false
        }
    }

    var profileKindLabel: String {
        isEffectProfile ? "effect" : "speech"
    }

    var baseFrequency: Double {
        switch self {
        case .cute:   return 470
        case .calm:   return 390
        case .deep:   return 310
        case .tiny:   return 640
        case .robot:  return 430
        case .arcade: return 620
        }
    }

    var charDuration: Double {
        switch self {
        case .cute:   return 0.054
        case .calm:   return 0.066
        case .deep:   return 0.074
        case .tiny:   return 0.044
        case .robot:  return 0.050
        case .arcade: return 0.038
        }
    }

    var gapDuration: Double {
        switch self {
        case .calm, .deep: return 0.011
        case .arcade, .tiny: return 0.006
        default: return 0.008
        }
    }

    var pitchJitterHz: Double {
        switch self {
        case .calm, .deep: return 10
        case .robot: return 14
        case .arcade: return 28
        default: return 18
        }
    }

    var waveform: BubbleSpeechWaveform {
        switch self {
        case .robot: return .squareSoft
        case .arcade: return .sine
        default: return .triangle
        }
    }
}

struct BubbleSpeechConfig: Sendable {
    var sampleRate: Double = 44100
    var baseFrequency: Double = 470
    var pitchJitterHz: Double = 12
    var charDuration: Double = 0.072
    var gapDuration: Double = 0.014
    var attack: Double = 0.004
    var release: Double = 0.020
    var waveform: BubbleSpeechWaveform = .triangle
    var speed: Double = 1.0
    var voiceProfile: BubbleSpeechVoiceProfile = .cute
    var characterTuning: BubbleSpeechCharacterTuning = .neutral

    static func from(profile: BubbleSpeechVoiceProfile, speed: Double = 1.0) -> BubbleSpeechConfig {
        BubbleSpeechConfig(
            sampleRate: 44100,
            baseFrequency: profile.baseFrequency,
            pitchJitterHz: profile.pitchJitterHz,
            charDuration: profile.charDuration,
            gapDuration: profile.gapDuration,
            attack: profile.isEffectProfile ? 0.003 : 0.005,
            release: profile.isEffectProfile ? 0.014 : 0.024,
            waveform: profile.waveform,
            speed: speed,
            voiceProfile: profile,
            characterTuning: .neutral
        )
    }

    var effectiveCharDuration: Double {
        guard speed > 0 else { return charDuration }
        return charDuration / speed
    }

    var effectiveGapDuration: Double {
        guard speed > 0 else { return gapDuration }
        return gapDuration / speed
    }
}

// MARK: - Syllable Model

struct BubbleSpeechSyllableFrame: Sendable {
    let char: Character
    let parts: KoreanSyllableParts
    let baseFrequency: Double
    let vowelColor: BubbleSpeechVowelColor
    let consonantTransient: BubbleSpeechTransientKind
    let finalTail: BubbleSpeechTailKind
    let duration: Double
    let gap: Double
    let phrasePosition: BubbleSpeechPhrasePosition
}

enum BubbleSpeechVowelColor: Sendable {
    case bright
    case neutral
    case round
    case dark
    case narrow
}

enum BubbleSpeechTransientKind: Sendable {
    case none
    case softClick
    case noiseTap
    case pluck
    case breath
}

enum BubbleSpeechTailKind: Sendable {
    case none
    case shortCut
    case nasalHum
    case softStop
}

enum BubbleSpeechPhrasePosition: Sendable {
    case start
    case middle
    case endFalling
    case endRising
}

enum BubbleSpeechToken: Sendable {
    case syllable(Character)
    case shortPause
    case mediumPause
    case longPause(ending: BubbleSpeechPhrasePosition)
}

struct BubbleSpeechGrain: Sendable, Equatable {
    let samples: [Float]
    let rms: Float
    let zeroCrossingRate: Float
    let spectralCentroid: Float
    let voicingConfidence: Float
}

struct BubbleSpeechGrainBank: Sendable, Equatable {
    let bright: [BubbleSpeechGrain]
    let neutral: [BubbleSpeechGrain]
    let round: [BubbleSpeechGrain]
    let dark: [BubbleSpeechGrain]
    let narrow: [BubbleSpeechGrain]

    var allGrains: [BubbleSpeechGrain] {
        bright + neutral + round + dark + narrow
    }

    func grains(for color: BubbleSpeechVowelColor) -> [BubbleSpeechGrain] {
        let preferred: [BubbleSpeechGrain]
        switch color {
        case .bright: preferred = bright
        case .neutral: preferred = neutral
        case .round: preferred = round
        case .dark: preferred = dark
        case .narrow: preferred = narrow
        }
        return preferred.isEmpty ? allGrains : preferred
    }
}

enum BubbleSpeechGrainAnalyzer {
    static func analyze(samples: [Float], sampleRate: Int) -> BubbleSpeechGrainBank? {
        guard sampleRate > 0, samples.count >= sampleRate / 20 else { return nil }
        guard samples.allSatisfy(\.isFinite) else { return nil }

        let windowSize = max(64, Int(Double(sampleRate) * 0.032))
        let hopSize = max(32, Int(Double(sampleRate) * 0.016))
        guard samples.count >= windowSize else { return nil }

        let analysisWindow = max(32, Int(Double(sampleRate) * 0.010))
        var windowRMS: [Float] = []
        var cursor = 0
        while cursor + analysisWindow <= samples.count {
            windowRMS.append(rms(Array(samples[cursor..<(cursor + analysisWindow)])))
            cursor += analysisWindow
        }
        guard let overallRMS = windowRMS.max(), overallRMS > 0.008 else { return nil }

        let sortedRMS = windowRMS.sorted()
        let lowerQuartile = sortedRMS[max(0, sortedRMS.count / 4 - 1)]
        let voicedThreshold = max(0.008, min(lowerQuartile * 2.5, overallRMS * 0.65))

        var candidates: [BubbleSpeechGrain] = []
        cursor = 0
        while cursor + windowSize <= samples.count, candidates.count < 120 {
            let raw = Array(samples[cursor..<(cursor + windowSize)])
            let rawRMS = rms(raw)
            if rawRMS >= voicedThreshold {
                let windowed = hannWindow(raw)
                let zcr = zeroCrossingRate(windowed, sampleRate: sampleRate)
                let centroid = spectralColorEstimate(windowed, sampleRate: sampleRate)
                let confidence = min(1, max(0, (rawRMS - voicedThreshold) / max(0.001, overallRMS - voicedThreshold)))
                candidates.append(BubbleSpeechGrain(
                    samples: windowed,
                    rms: rawRMS,
                    zeroCrossingRate: zcr,
                    spectralCentroid: centroid,
                    voicingConfidence: confidence
                ))
            }
            cursor += hopSize
        }
        guard candidates.count >= 4 else { return nil }

        let centroids = candidates.map(\.spectralCentroid).sorted()
        let median = centroids[centroids.count / 2]
        var bright: [BubbleSpeechGrain] = []
        var neutral: [BubbleSpeechGrain] = []
        var round: [BubbleSpeechGrain] = []
        var dark: [BubbleSpeechGrain] = []
        var narrow: [BubbleSpeechGrain] = []

        for grain in candidates {
            let ratio = grain.spectralCentroid / max(1, median)
            if ratio >= 1.24 {
                append(grain, to: &bright)
            } else if ratio >= 1.08 {
                append(grain, to: &narrow)
            } else if ratio <= 0.76 {
                append(grain, to: &dark)
            } else if ratio <= 0.92 {
                append(grain, to: &round)
            } else {
                append(grain, to: &neutral)
            }
        }

        return BubbleSpeechGrainBank(
            bright: bright,
            neutral: neutral,
            round: round,
            dark: dark,
            narrow: narrow
        )
    }

    private static func append(_ grain: BubbleSpeechGrain, to grains: inout [BubbleSpeechGrain]) {
        if grains.count < 24 { grains.append(grain) }
    }

    private static func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(0.0) { $0 + Double($1 * $1) }
        return Float(sqrt(sum / Double(samples.count)))
    }

    private static func hannWindow(_ samples: [Float]) -> [Float] {
        guard samples.count > 1 else { return samples }
        let denominator = Double(samples.count - 1)
        return samples.enumerated().map { index, sample in
            let gain = 0.5 - 0.5 * cos(2 * .pi * Double(index) / denominator)
            return sample * Float(gain)
        }
    }

    private static func zeroCrossingRate(_ samples: [Float], sampleRate: Int) -> Float {
        guard samples.count > 1 else { return 0 }
        var crossings = 0
        for index in 1..<samples.count where (samples[index - 1] < 0) != (samples[index] < 0) {
            crossings += 1
        }
        return Float(crossings) * Float(sampleRate) / Float(samples.count)
    }

    private static func spectralColorEstimate(_ samples: [Float], sampleRate: Int) -> Float {
        guard samples.count > 1 else { return 0 }
        var variation: Double = 0
        var magnitude: Double = 0
        for index in 1..<samples.count {
            variation += Double(abs(samples[index] - samples[index - 1]))
            magnitude += Double(abs(samples[index]))
        }
        let normalized = variation / max(0.000_001, magnitude)
        return Float(min(Double(sampleRate) / 2, normalized * Double(sampleRate) / (2 * .pi)))
    }
}

enum BubbleSpeechCharacterRenderer {
    static func render(
        text: String,
        bank: BubbleSpeechGrainBank,
        sampleRate: Int,
        config: BubbleSpeechConfig,
        segmentRate: Float
    ) -> [Float] {
        guard sampleRate > 0, !bank.allGrains.isEmpty else { return [] }
        let tokens = BubbleSpeechSynthesizer.tokenize(text)
        let syllableCount = tokens.reduce(0) { count, token in
            if case .syllable = token { return count + 1 }
            return count
        }
        guard syllableCount > 0 else { return [] }

        let safeRate = max(0.85, min(1.25, Double(segmentRate)))
        let crossfadeFrames = max(32, Int(Double(sampleRate) * 0.004))
        var output: [Float] = []
        var syllableIndex = 0
        var nextPosition: BubbleSpeechPhrasePosition = .start

        for (tokenIndex, token) in tokens.enumerated() {
            switch token {
            case .syllable(let character):
                let terminal = BubbleSpeechSynthesizer.terminalPhrasePosition(after: tokenIndex, in: tokens)
                let position = terminal ?? nextPosition
                nextPosition = .middle
                let parts = KoreanSyllableDecomposer.decompose(character)
                let color = BubbleSpeechSynthesizer.vowelColor(for: parts.medialIndex)
                let candidates = bank.grains(for: color)
                guard !candidates.isEmpty else { return [] }
                let repeatPattern = config.characterTuning.grainRepeatPattern
                let repeatValue = repeatPattern.isEmpty ? 1 : repeatPattern[syllableIndex % repeatPattern.count]
                let grain = candidates[stableIndex(
                    for: character,
                    syllableIndex: syllableIndex * max(1, repeatValue),
                    count: candidates.count
                )]

                let frame = BubbleSpeechSyllableFrame(
                    char: character,
                    parts: parts,
                    baseFrequency: config.baseFrequency,
                    vowelColor: color,
                    consonantTransient: BubbleSpeechSynthesizer.transientKind(for: parts.initialIndex),
                    finalTail: BubbleSpeechSynthesizer.tailKind(for: parts.finalIndex),
                    duration: config.effectiveCharDuration,
                    gap: config.effectiveGapDuration,
                    phrasePosition: position
                )
                let frequency = BubbleSpeechSynthesizer.speechFrequency(
                    for: frame,
                    config: config,
                    index: syllableIndex,
                    total: syllableCount
                )
                let pitchPattern = config.characterTuning.pitchStepPattern
                let patternCents = pitchPattern.isEmpty ? 0 : pitchPattern[syllableIndex % pitchPattern.count]
                let identityRatio = pow(2, patternCents / 1_200)
                let formantRatio = 1 + Double(config.characterTuning.formantColor) * 0.04
                let pitchRatio = min(
                    1.34,
                    max(0.76, frequency / max(1, config.baseFrequency) * identityRatio * formantRatio)
                )
                let duration = targetDuration(for: frame, config: config, segmentRate: safeRate)
                var segment = loopedGrain(
                    grain.samples,
                    targetCount: max(64, Int(duration * Double(sampleRate))),
                    pitchRatio: pitchRatio
                )
                applySyllableEnvelope(&segment)
                let accents = config.characterTuning.accentPattern
                let accent = accents.isEmpty ? 1 : accents[syllableIndex % accents.count]
                if accent != 1 {
                    for index in segment.indices { segment[index] *= accent }
                }
                appendWithCrossfade(segment, to: &output, frames: crossfadeFrames)

                let gapFrames = max(0, Int(frame.gap * config.characterTuning.gapScale / safeRate * Double(sampleRate)))
                if gapFrames > 0 {
                    output.append(contentsOf: [Float](repeating: 0, count: gapFrames))
                }
                syllableIndex += 1

            case .shortPause:
                appendSilence(seconds: 0.012 / safeRate, sampleRate: sampleRate, to: &output)
                nextPosition = .start
            case .mediumPause:
                appendSilence(seconds: 0.030 / safeRate, sampleRate: sampleRate, to: &output)
                nextPosition = .start
            case .longPause:
                appendSilence(seconds: 0.055 / safeRate, sampleRate: sampleRate, to: &output)
                nextPosition = .start
            }
        }
        return output
    }

    private static func targetDuration(
        for frame: BubbleSpeechSyllableFrame,
        config: BubbleSpeechConfig,
        segmentRate: Double
    ) -> Double {
        let profileDuration = frame.duration / segmentRate
        let tailScale = frame.finalTail == .shortCut ? 0.88 : 1.0
        return min(
            config.characterTuning.maxSegmentDuration,
            max(config.characterTuning.minSegmentDuration, profileDuration * tailScale)
        )
    }

    private static func stableIndex(for character: Character, syllableIndex: Int, count: Int) -> Int {
        guard count > 1 else { return 0 }
        let scalarValue = character.unicodeScalars.reduce(0) { partial, scalar in
            partial &* 31 &+ Int(scalar.value)
        }
        return abs(scalarValue &+ syllableIndex &* 17) % count
    }

    private static func loopedGrain(_ grain: [Float], targetCount: Int, pitchRatio: Double) -> [Float] {
        guard !grain.isEmpty, targetCount > 0 else { return [] }
        let lastIndex = max(1, grain.count - 1)
        return (0..<targetCount).map { index in
            let position = (Double(index) * pitchRatio).truncatingRemainder(dividingBy: Double(lastIndex))
            let lower = Int(position)
            let upper = min(lastIndex, lower + 1)
            let fraction = Float(position - Double(lower))
            return grain[lower] * (1 - fraction) + grain[upper] * fraction
        }
    }

    private static func applySyllableEnvelope(_ samples: inout [Float]) {
        guard samples.count > 1 else { return }
        let denominator = Double(samples.count - 1)
        for index in samples.indices {
            let progress = Double(index) / denominator
            let envelope = sin(.pi * progress)
            samples[index] *= Float(envelope * 1.18)
        }
    }

    private static func appendWithCrossfade(_ segment: [Float], to output: inout [Float], frames: Int) {
        guard !segment.isEmpty else { return }
        guard !output.isEmpty else {
            output.append(contentsOf: segment)
            return
        }
        let overlap = min(frames, output.count, segment.count)
        guard overlap > 0 else {
            output.append(contentsOf: segment)
            return
        }
        let start = output.count - overlap
        for index in 0..<overlap {
            let progress = Float(index + 1) / Float(overlap + 1)
            output[start + index] = output[start + index] * (1 - progress) + segment[index] * progress
        }
        output.append(contentsOf: segment.dropFirst(overlap))
    }

    private static func appendSilence(seconds: Double, sampleRate: Int, to output: inout [Float]) {
        output.append(contentsOf: [Float](repeating: 0, count: max(1, Int(seconds * Double(sampleRate)))))
    }
}

// MARK: - Synthesizer

enum BubbleSpeechSynthesizer {

    static func applyAdaptiveEffect(
        text: String,
        voiceSamples: [Float],
        sampleRate: Int,
        config: BubbleSpeechConfig,
        segmentRate: Float,
        decision: BubbleSpeechEffectDecision
    ) -> [Float]? {
        guard !voiceSamples.isEmpty, sampleRate > 0 else { return nil }
        if decision.strength == .bypass { return voiceSamples }

        let rendered = renderSourceAlignedEffect(
            text: text,
            voiceSamples: voiceSamples,
            sampleRate: sampleRate,
            config: config
        )
        guard !rendered.isEmpty else { return nil }
        let durationRatio = BubbleSpeechSynthesizer.durationRatio(
            renderedSamples: rendered,
            sourceSamples: voiceSamples
        )
        guard durationRatio >= decision.minimumSourceDurationRatio,
              durationRatio <= 1.20 else { return nil }

        let wet = min(1, max(0, decision.wetMix))
        let dry = resample(voiceSamples, targetCount: rendered.count)
        var mixed = [Float]()
        mixed.reserveCapacity(rendered.count)
        for index in rendered.indices {
            let value = dry[index] * (1 - wet) + rendered[index] * wet
            mixed.append(max(-0.98, min(0.98, value)))
        }
        return mixed
    }

    /// Keeps the complete Supertonic3 waveform and adds only gentle syllable
    /// boundary articulation. The procedural guide validates the text rhythm,
    /// but its synthetic tone is never mixed into product speech.
    static func renderSourceAlignedEffect(
        text: String,
        voiceSamples: [Float],
        sampleRate: Int,
        config: BubbleSpeechConfig
    ) -> [Float] {
        guard !voiceSamples.isEmpty, sampleRate > 0 else { return [] }
        let syllables = syllableCount(in: text)
        guard syllables > 0 else { return [] }
        let guide = synthesize(text: text, config: config)
        guard !guide.isEmpty else { return [] }

        var energy: Double = 0
        for sample in voiceSamples {
            guard sample.isFinite else { return [] }
            energy += Double(sample * sample)
        }
        guard sqrt(energy / Double(voiceSamples.count)) > 0.001 else { return [] }

        var output = voiceSamples
        let accents = config.characterTuning.accentPattern
        let fadeFrames = max(24, Int(Double(sampleRate) * 0.0045))

        for syllableIndex in 0..<syllables {
            let start = syllableIndex * voiceSamples.count / syllables
            let end = (syllableIndex + 1) * voiceSamples.count / syllables
            guard end > start else { continue }

            let segmentLength = end - start
            let boundaryFrames = min(fadeFrames, max(1, segmentLength / 5))
            let accent = accents.isEmpty ? Float(1) : accents[syllableIndex % accents.count]
            let accentGain = Float(1) + (accent - 1) * 0.18

            for index in start..<end {
                let localIndex = index - start
                let distanceToBoundary = min(localIndex, end - index - 1)
                let boundaryProgress = min(1, Float(distanceToBoundary) / Float(boundaryFrames))
                let boundaryGain = Float(0.88) + Float(0.12) * boundaryProgress
                output[index] = max(-0.98, min(0.98, voiceSamples[index] * boundaryGain * accentGain))
            }
        }

        return output
    }

    static func renderVoiceBasedEffect(
        text: String,
        voiceSamples: [Float],
        sampleRate: Int,
        config: BubbleSpeechConfig,
        segmentRate: Float = 1.0
    ) -> [Float] {
        guard !voiceSamples.isEmpty, sampleRate > 0 else { return [] }

        let tokens = tokenize(text)
        let syllableCount = tokens.reduce(0) { total, token in
            if case .syllable = token { return total + 1 }
            return total
        }
        guard syllableCount > 0 else { return [] }

        let guide = synthesize(text: text, config: config)
        guard !guide.isEmpty else { return [] }

        guard let grainBank = BubbleSpeechGrainAnalyzer.analyze(samples: voiceSamples, sampleRate: sampleRate) else {
            return []
        }
        let choppedVoice = BubbleSpeechCharacterRenderer.render(
            text: text,
            bank: grainBank,
            sampleRate: sampleRate,
            config: config,
            segmentRate: segmentRate
        )
        guard !choppedVoice.isEmpty else { return [] }

        var output: [Float] = []
        output.reserveCapacity(choppedVoice.count)
        let guideSupport = resample(guide, targetCount: choppedVoice.count)
        let guideEnvelope = smoothedEnvelope(from: guideSupport, window: max(24, sampleRate / 360))
        let maxEnvelope = max(0.001, guideEnvelope.max() ?? 0)
        let guideGain = config.characterTuning.guideGain
        let shimmerDepth = config.characterTuning.shimmerDepth

        for i in choppedVoice.indices {
            let gate = Float(min(1.0, guideEnvelope[i] / maxEnvelope))
            let guideSample = guideSupport[i] * guideGain * gate
            let t = Double(i) / Double(sampleRate)
            let shimmer = Float(1.0 - Double(shimmerDepth) + Double(shimmerDepth) * sin(2.0 * .pi * 54.0 * t))
            let shapedVoice = softClip(Double(choppedVoice[i] * shimmer))
            let mixed = shapedVoice + Double(guideSample)
            output.append(Float(max(-0.98, min(0.98, mixed))))
        }

        smoothEdges(&output, sampleRate: Double(sampleRate), attack: 0.006, release: 0.028)
        return output
    }

    static func meanAbsoluteDelta(_ lhs: [Float], _ rhs: [Float]) -> Float {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        let rhsComparable = lhs.count == rhs.count ? rhs : resample(rhs, targetCount: lhs.count)
        var total: Double = 0
        for i in lhs.indices {
            total += Double(abs(lhs[i] - rhsComparable[i]))
        }
        return Float(total / Double(lhs.count))
    }

    static func durationRatio(renderedSamples: [Float], sourceSamples: [Float]) -> Double {
        guard !renderedSamples.isEmpty, !sourceSamples.isEmpty else { return 0 }
        return Double(renderedSamples.count) / Double(sourceSamples.count)
    }

    static func syllableCount(in text: String) -> Int {
        tokenize(text).reduce(0) { total, token in
            if case .syllable = token { return total + 1 }
            return total
        }
    }

    static func synthesize(text: String, config: BubbleSpeechConfig) -> [Float] {
        let tokens = tokenize(text)
        let syllableCount = tokens.reduce(0) { total, token in
            if case .syllable = token { return total + 1 }
            return total
        }
        guard syllableCount > 0 else { return [] }

        var output: [Float] = []
        var syllableIndex = 0
        var nextPosition: BubbleSpeechPhrasePosition = .start

        for (tokenIndex, token) in tokens.enumerated() {
            switch token {
            case .syllable(let char):
                let terminalPosition = terminalPhrasePosition(after: tokenIndex, in: tokens)
                let phrasePosition = terminalPosition ?? nextPosition
                nextPosition = .middle

                let parts = KoreanSyllableDecomposer.decompose(char)
                let frame = BubbleSpeechSyllableFrame(
                    char: char,
                    parts: parts,
                    baseFrequency: config.baseFrequency,
                    vowelColor: vowelColor(for: parts.medialIndex),
                    consonantTransient: transientKind(for: parts.initialIndex),
                    finalTail: tailKind(for: parts.finalIndex),
                    duration: config.effectiveCharDuration,
                    gap: config.effectiveGapDuration,
                    phrasePosition: phrasePosition
                )
                output.append(contentsOf: generateSyllable(frame: frame, config: config, index: syllableIndex, total: syllableCount))
                output.append(contentsOf: silence(duration: frame.gap * 0.32, sampleRate: config.sampleRate))
                syllableIndex += 1

            case .shortPause:
                output.append(contentsOf: silence(duration: 0.018 / max(0.25, config.speed), sampleRate: config.sampleRate))
                nextPosition = .start

            case .mediumPause:
                output.append(contentsOf: silence(duration: 0.052 / max(0.25, config.speed), sampleRate: config.sampleRate))
                nextPosition = .start

            case .longPause(let ending):
                output.append(contentsOf: silence(duration: 0.105 / max(0.25, config.speed), sampleRate: config.sampleRate))
                nextPosition = ending == .endRising ? .start : .start
            }
        }

        output.append(contentsOf: silence(duration: 0.040, sampleRate: config.sampleRate))
        return output
    }

    static func vowelColor(for medialIndex: Int?) -> BubbleSpeechVowelColor {
        guard let medialIndex else { return .neutral }
        switch medialIndex {
        case 0, 2, 1, 3:
            return .bright
        case 8, 12, 9, 10, 11:
            return .round
        case 4, 6, 5, 7:
            return .dark
        case 13, 17, 18, 20, 14, 15, 16, 19:
            return .narrow
        default:
            return .neutral
        }
    }

    static func transientKind(for initialIndex: Int?) -> BubbleSpeechTransientKind {
        guard let initialIndex else { return .softClick }
        switch initialIndex {
        case 0, 1, 15, 16, 17, 18:
            return .pluck
        case 2, 6, 11:
            return .softClick
        case 3, 7:
            return .none
        case 9, 10, 14:
            return .breath
        case 4, 5:
            return .pluck
        case 12, 13:
            return .noiseTap
        default:
            return .softClick
        }
    }

    static func tailKind(for finalIndex: Int?) -> BubbleSpeechTailKind {
        guard let finalIndex, finalIndex > 0 else { return .none }
        switch finalIndex {
        case 4, 16, 21:
            return .nasalHum
        case 1, 2, 3, 7, 18:
            return .softStop
        case 8:
            return .shortCut
        case 19, 20, 27:
            return .softStop
        default:
            return .shortCut
        }
    }

    static func speechFrequency(
        for frame: BubbleSpeechSyllableFrame,
        config: BubbleSpeechConfig,
        index: Int,
        total: Int
    ) -> Double {
        let vowelOffset: Double
        switch frame.vowelColor {
        case .bright: vowelOffset = 42
        case .round: vowelOffset = 12
        case .neutral: vowelOffset = 0
        case .dark: vowelOffset = -34
        case .narrow: vowelOffset = 28
        }

        let phraseOffset: Double
        switch frame.phrasePosition {
        case .start: phraseOffset = 24
        case .middle: phraseOffset = 0
        case .endFalling: phraseOffset = -52
        case .endRising: phraseOffset = 58
        }

        let progress = total > 1 ? Double(index) / Double(total - 1) : 0
        let contour = (0.5 - progress) * 26.0
        let bounce = index.isMultiple(of: 2) ? 10.0 : -6.0
        let jitter = deterministicJitter(for: frame.char, index: index, range: config.pitchJitterHz)
        let frequency = config.baseFrequency + vowelOffset + phraseOffset + contour + bounce + jitter
        return min(config.baseFrequency * 1.35, max(config.baseFrequency * 0.75, frequency))
    }

    static func generateSyllable(
        frame: BubbleSpeechSyllableFrame,
        config: BubbleSpeechConfig,
        index: Int,
        total: Int
    ) -> [Float] {
        let frequency = speechFrequency(for: frame, config: config, index: index, total: total)
        let duration = frame.finalTail == .shortCut ? frame.duration * 0.82 : frame.duration
        let transientDuration = transientDuration(for: frame.consonantTransient)
        let tailDuration = tailDuration(for: frame.finalTail)
        let bodyDuration = max(0.018, duration - transientDuration - tailDuration)

        var samples: [Float] = []
        samples.append(contentsOf: generateTransient(kind: frame.consonantTransient, frequency: frequency, duration: transientDuration, sampleRate: config.sampleRate, seed: index))
        samples.append(contentsOf: generateVowelBody(frame: frame, frequency: frequency, duration: bodyDuration, config: config))
        samples.append(contentsOf: generateTail(kind: frame.finalTail, frequency: frequency, duration: tailDuration, sampleRate: config.sampleRate))
        smoothEdges(&samples, sampleRate: config.sampleRate, attack: config.attack, release: config.release)
        return samples
    }

    // MARK: - Token / Phrase

    static func tokenize(_ text: String) -> [BubbleSpeechToken] {
        var tokens: [BubbleSpeechToken] = []
        for char in text {
            if char == "\n" || char == "\r" {
                tokens.append(.longPause(ending: .endFalling))
            } else if char.isWhitespace {
                tokens.append(.shortPause)
            } else if ",，、/·".contains(char) {
                tokens.append(.mediumPause)
            } else if "?？".contains(char) {
                tokens.append(.longPause(ending: .endRising))
            } else if "!！".contains(char) {
                tokens.append(.longPause(ending: .endRising))
            } else if ".。".contains(char) {
                tokens.append(.longPause(ending: .endFalling))
            } else if isVoicedChar(char) {
                tokens.append(.syllable(char))
            }
        }
        return tokens
    }

    static func terminalPhrasePosition(after tokenIndex: Int, in tokens: [BubbleSpeechToken]) -> BubbleSpeechPhrasePosition? {
        var cursor = tokenIndex + 1
        while cursor < tokens.count {
            switch tokens[cursor] {
            case .syllable:
                return nil
            case .shortPause, .mediumPause:
                cursor += 1
            case .longPause(let ending):
                return ending
            }
        }
        return .endFalling
    }

    // MARK: - Segments

    private static func generateTransient(
        kind: BubbleSpeechTransientKind,
        frequency: Double,
        duration: Double,
        sampleRate: Double,
        seed: Int
    ) -> [Float] {
        guard duration > 0 else { return [] }
        let count = max(1, Int(duration * sampleRate))
        return (0..<count).map { i in
            let t = Double(i) / sampleRate
            let envelope = 1.0 - Double(i) / Double(max(1, count))
            let noise = pseudoNoise(index: i, seed: seed)
            let click = sin(2.0 * .pi * frequency * 1.8 * t)
            let value: Double
            switch kind {
            case .none:
                value = 0
            case .softClick:
                value = click * 0.08
            case .noiseTap:
                value = (noise * 0.16 + click * 0.04)
            case .pluck:
                value = (click * 0.14 + noise * 0.04)
            case .breath:
                value = noise * 0.10
            }
            return Float(value * envelope)
        }
    }

    private static func generateVowelBody(
        frame: BubbleSpeechSyllableFrame,
        frequency: Double,
        duration: Double,
        config: BubbleSpeechConfig
    ) -> [Float] {
        let count = max(1, Int(duration * config.sampleRate))
        let amplitude = config.voiceProfile.isEffectProfile ? 0.32 : 0.40

        return (0..<count).map { i in
            let t = Double(i) / config.sampleRate
            let progress = Double(i) / Double(max(1, count - 1))
            let glide = syllableGlideCents(position: frame.phrasePosition, progress: progress)
            let localFrequency = frequency * pow(2.0, glide / 1200.0)
            let raw = oscillatorMix(
                t: t,
                frequency: localFrequency,
                vowelColor: frame.vowelColor,
                waveform: config.waveform
            )
            let envelope = vowelEnvelope(sample: i, count: count)
            let tremolo = 0.94 + 0.06 * sin(2.0 * .pi * 38.0 * t)
            return Float(raw * envelope * amplitude * tremolo)
        }
    }

    private static func generateTail(
        kind: BubbleSpeechTailKind,
        frequency: Double,
        duration: Double,
        sampleRate: Double
    ) -> [Float] {
        guard duration > 0 else { return [] }
        let count = max(1, Int(duration * sampleRate))
        return (0..<count).map { i in
            let t = Double(i) / sampleRate
            let envelope = 1.0 - Double(i) / Double(max(1, count))
            let value: Double
            switch kind {
            case .none:
                value = 0
            case .shortCut:
                value = 0
            case .nasalHum:
                value = sin(2.0 * .pi * frequency * 0.50 * t) * 0.12
            case .softStop:
                value = sin(2.0 * .pi * frequency * 0.75 * t) * 0.06
            }
            return Float(value * envelope)
        }
    }

    private static func oscillatorMix(
        t: Double,
        frequency: Double,
        vowelColor: BubbleSpeechVowelColor,
        waveform: BubbleSpeechWaveform
    ) -> Double {
        let base = baseWave(t: t, frequency: frequency, waveform: waveform)
        let second = sin(2.0 * .pi * frequency * 2.0 * t)
        let low = sin(2.0 * .pi * frequency * 0.5 * t)
        let high = sin(2.0 * .pi * frequency * 3.0 * t)
        let formant = vowelResonance(t: t, vowelColor: vowelColor)

        switch vowelColor {
        case .bright:
            return base * 0.70 + second * 0.16 + high * 0.04 + formant * 0.10
        case .round:
            return base * 0.66 + low * 0.20 + second * 0.04 + formant * 0.10
        case .neutral:
            return base * 0.78 + second * 0.10 + formant * 0.12
        case .dark:
            return base * 0.62 + low * 0.26 + second * 0.03 + formant * 0.09
        case .narrow:
            return base * 0.68 + second * 0.08 + high * 0.13 + formant * 0.11
        }
    }

    private static func vowelResonance(t: Double, vowelColor: BubbleSpeechVowelColor) -> Double {
        let bands: (Double, Double, Double)
        switch vowelColor {
        case .bright:
            bands = (760, 1180, 2360)
        case .round:
            bands = (520, 900, 1760)
        case .neutral:
            bands = (610, 1040, 1980)
        case .dark:
            bands = (430, 820, 1560)
        case .narrow:
            bands = (690, 1460, 2600)
        }
        let first = sin(2.0 * .pi * bands.0 * t) * 0.55
        let second = sin(2.0 * .pi * bands.1 * t) * 0.30
        let third = sin(2.0 * .pi * bands.2 * t) * 0.15
        return first + second + third
    }

    private static func syllableGlideCents(position: BubbleSpeechPhrasePosition, progress: Double) -> Double {
        let center = sin(progress * .pi) * 8.0
        switch position {
        case .start:
            return 10.0 - progress * 14.0 + center
        case .middle:
            return 5.0 - progress * 8.0 + center
        case .endFalling:
            return 4.0 - progress * 26.0 + center * 0.4
        case .endRising:
            return -8.0 + progress * 28.0 + center * 0.5
        }
    }

    private static func baseWave(t: Double, frequency: Double, waveform: BubbleSpeechWaveform) -> Double {
        let phase = (t * frequency).truncatingRemainder(dividingBy: 1.0)
        switch waveform {
        case .sine:
            return sin(2.0 * .pi * phase)
        case .triangle:
            return phase < 0.5 ? 4.0 * phase - 1.0 : 3.0 - 4.0 * phase
        case .squareSoft:
            let raw = phase < 0.5 ? 1.0 : -1.0
            return tanh(raw * 2.2)
        case .noiseBlend:
            return sin(2.0 * .pi * phase) * 0.88 + pseudoNoise(index: Int(t * 44100), seed: 17) * 0.12
        }
    }

    private static func vowelEnvelope(sample: Int, count: Int) -> Double {
        let attackCount = max(1, Int(Double(count) * 0.18))
        let releaseCount = max(1, Int(Double(count) * 0.32))
        if sample < attackCount {
            return Double(sample) / Double(attackCount)
        }
        if sample > count - releaseCount {
            return max(0, Double(count - sample) / Double(releaseCount))
        }
        return 1.0
    }

    private static func transientDuration(for kind: BubbleSpeechTransientKind) -> Double {
        switch kind {
        case .none: return 0
        case .softClick: return 0.005
        case .noiseTap: return 0.008
        case .pluck: return 0.010
        case .breath: return 0.012
        }
    }

    private static func tailDuration(for kind: BubbleSpeechTailKind) -> Double {
        switch kind {
        case .none: return 0
        case .shortCut: return 0.006
        case .nasalHum: return 0.018
        case .softStop: return 0.010
        }
    }

    private static func smoothEdges(_ samples: inout [Float], sampleRate: Double, attack: Double, release: Double) {
        guard !samples.isEmpty else { return }
        let attackSamples = min(Int(attack * sampleRate), samples.count / 3)
        let releaseSamples = min(Int(release * sampleRate), samples.count / 3)

        if attackSamples > 0 {
            for i in 0..<attackSamples {
                samples[i] *= Float(Double(i) / Double(max(1, attackSamples)))
            }
        }
        if releaseSamples > 0 {
            for i in 0..<releaseSamples {
                let idx = samples.count - 1 - i
                samples[idx] *= Float(Double(i) / Double(max(1, releaseSamples)))
            }
        }
    }

    private static func silence(duration: Double, sampleRate: Double) -> [Float] {
        [Float](repeating: 0, count: max(1, Int(duration * sampleRate)))
    }

    private static func resample(_ samples: [Float], targetCount: Int) -> [Float] {
        guard targetCount > 0 else { return [] }
        guard samples.count > 1 else { return [Float](repeating: samples.first ?? 0, count: targetCount) }
        if samples.count == targetCount { return samples }

        let scale = Double(samples.count - 1) / Double(max(1, targetCount - 1))
        return (0..<targetCount).map { index in
            let source = Double(index) * scale
            let left = Int(source)
            let right = min(samples.count - 1, left + 1)
            let fraction = Float(source - Double(left))
            return samples[left] * (1 - fraction) + samples[right] * fraction
        }
    }

    private static func smoothedEnvelope(from samples: [Float], window: Int) -> [Double] {
        guard !samples.isEmpty else { return [] }
        let width = max(1, window)
        var envelope = [Double](repeating: 0, count: samples.count)
        var running = 0.0
        for i in samples.indices {
            running += Double(abs(samples[i]))
            if i >= width {
                running -= Double(abs(samples[i - width]))
            }
            envelope[i] = running / Double(min(width, i + 1))
        }
        return envelope
    }

    private static func softClip(_ value: Double) -> Double {
        tanh(value * 1.35) / tanh(1.35)
    }

    private static func deterministicJitter(for char: Character, index: Int, range: Double) -> Double {
        let scalar = Int(char.unicodeScalars.first?.value ?? 65)
        let mixed = (scalar &* 31 &+ index &* 17) % 997
        let unit = Double(mixed) / 996.0
        return (unit * 2.0 - 1.0) * range
    }

    private static func pseudoNoise(index: Int, seed: Int) -> Double {
        let value = UInt64(index &* 1103515245 &+ seed &* 12345)
        let mixed = (value ^ (value >> 16)) & 0xffff
        return (Double(mixed) / 32767.5) - 1.0
    }

    private static func isVoicedChar(_ char: Character) -> Bool {
        guard let scalar = char.unicodeScalars.first else { return false }
        if KoreanSyllableDecomposer.isHangulSyllable(scalar.value) { return true }
        return CharacterSet.alphanumerics.contains(scalar)
    }
}
