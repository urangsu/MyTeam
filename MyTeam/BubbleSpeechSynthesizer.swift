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
//   - Lab-only speech effect, not a fallback TTS.
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
            voiceProfile: profile
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

// MARK: - Synthesizer

enum BubbleSpeechSynthesizer {

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

        let choppedVoice = chopVoiceSamples(
            voiceSamples,
            tokens: tokens,
            syllableCount: syllableCount,
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
        let carrierGain: Float = config.voiceProfile.isEffectProfile ? 0.10 : 0.075

        for i in choppedVoice.indices {
            let gate = Float(min(1.0, guideEnvelope[i] / maxEnvelope))
            let guideSample = guideSupport[i] * carrierGain * gate
            let t = Double(i) / Double(sampleRate)
            let shimmer = Float(0.97 + 0.03 * sin(2.0 * .pi * 54.0 * t))
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

    private static func chopVoiceSamples(
        _ voiceSamples: [Float],
        tokens: [BubbleSpeechToken],
        syllableCount: Int,
        sampleRate: Int,
        config: BubbleSpeechConfig,
        segmentRate: Float
    ) -> [Float] {
        guard syllableCount > 0 else { return [] }

        let safeRate = max(0.85, min(1.25, Double(segmentRate)))
        let sourceStride = Double(voiceSamples.count) / Double(syllableCount)
        let crossfadeFrames = max(Int(0.003 * Double(sampleRate)), min(Int(0.008 * Double(sampleRate)), sampleRate / 160))
        var output: [Float] = []
        var syllableIndex = 0

        for token in tokens {
            switch token {
            case .syllable:
                let sourceStart = Int(Double(syllableIndex) * sourceStride)
                let sourceEnd = syllableIndex == syllableCount - 1
                    ? voiceSamples.count
                    : Int(Double(syllableIndex + 1) * sourceStride)
                let source = Array(voiceSamples[max(0, sourceStart)..<min(voiceSamples.count, max(sourceStart + 1, sourceEnd))])
                let targetCount = targetSegmentFrameCount(
                    sourceCount: source.count,
                    sampleRate: sampleRate,
                    config: config,
                    segmentRate: safeRate
                )
                var segment = resample(source, targetCount: targetCount)
                applyChopperEnvelope(&segment, sampleRate: sampleRate, config: config)
                appendWithCrossfade(segment, to: &output, crossfadeFrames: crossfadeFrames)

                let gapFrames = max(0, Int(config.effectiveGapDuration * 0.62 / safeRate * Double(sampleRate)))
                if gapFrames > 0 {
                    output.append(contentsOf: [Float](repeating: 0, count: gapFrames))
                }
                syllableIndex += 1

            case .shortPause:
                output.append(contentsOf: [Float](repeating: 0, count: max(1, Int(0.010 / safeRate * Double(sampleRate)))))

            case .mediumPause:
                output.append(contentsOf: [Float](repeating: 0, count: max(1, Int(0.024 / safeRate * Double(sampleRate)))))

            case .longPause:
                output.append(contentsOf: [Float](repeating: 0, count: max(1, Int(0.038 / safeRate * Double(sampleRate)))))
            }
        }

        smoothEdges(&output, sampleRate: Double(sampleRate), attack: 0.004, release: 0.018)
        return output
    }

    private static func targetSegmentFrameCount(
        sourceCount: Int,
        sampleRate: Int,
        config: BubbleSpeechConfig,
        segmentRate: Double
    ) -> Int {
        let profileDuration = config.effectiveCharDuration / segmentRate
        let minDuration = config.voiceProfile.isEffectProfile ? 0.026 : 0.034
        let maxDuration = config.voiceProfile.isEffectProfile ? 0.052 : 0.066
        let targetDuration = min(maxDuration, max(minDuration, profileDuration))
        let targetCount = Int(targetDuration * Double(sampleRate))
        return max(64, min(max(sourceCount, 64), targetCount))
    }

    private static func applyChopperEnvelope(_ samples: inout [Float], sampleRate: Int, config: BubbleSpeechConfig) {
        guard !samples.isEmpty else { return }
        let attack = config.voiceProfile.isEffectProfile ? 0.0025 : 0.004
        let release = config.voiceProfile.isEffectProfile ? 0.008 : 0.014
        smoothEdges(&samples, sampleRate: Double(sampleRate), attack: attack, release: release)
    }

    private static func appendWithCrossfade(_ segment: [Float], to output: inout [Float], crossfadeFrames: Int) {
        guard !segment.isEmpty else { return }
        guard !output.isEmpty, crossfadeFrames > 0 else {
            output.append(contentsOf: segment)
            return
        }

        let overlap = min(crossfadeFrames, output.count, segment.count)
        if overlap <= 0 {
            output.append(contentsOf: segment)
            return
        }

        let outputStart = output.count - overlap
        for i in 0..<overlap {
            let progress = Double(i + 1) / Double(overlap + 1)
            let fadeOut = Float(1.0 - progress)
            let fadeIn = Float(progress)
            output[outputStart + i] = output[outputStart + i] * fadeOut + segment[i] * fadeIn
        }
        if segment.count > overlap {
            output.append(contentsOf: segment[overlap...])
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

    private static func tokenize(_ text: String) -> [BubbleSpeechToken] {
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

    private static func terminalPhrasePosition(after tokenIndex: Int, in tokens: [BubbleSpeechToken]) -> BubbleSpeechPhrasePosition? {
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
