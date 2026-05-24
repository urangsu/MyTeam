import Foundation

// MARK: - AnimaleseSynthesizer
// Round 262TTS-ANIMALESE-SPEECHLIKE-ENGINE
//
// Round 261 used a melody-like blip engine: one character became one tone and
// pitch was selected from a major scale. That passed wiring tests but sounded
// like arcade notes. Round 262 switches to a speech-like syllable engine:
// consonant transient + vowel-colored body + final tail + phrase contour.
//
// Rules:
//   - No Nintendo/Animal Crossing original samples.
//   - No YouTube audio extraction.
//   - No external sample files.
//   - Pure procedural synthesis only.
//   - Lab-only speech effect, not a fallback TTS.

// MARK: - Wave / Profile

enum AnimaleseWaveform: String, CaseIterable, Sendable {
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

enum AnimaleseVoiceProfile: String, CaseIterable, Sendable, Identifiable {
    case cute
    case calm
    case deep
    case tiny
    case robot
    case arcade

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cute:   return "Cute speech"
        case .calm:   return "Calm speech"
        case .deep:   return "Deep speech"
        case .tiny:   return "Tiny speech"
        case .robot:  return "Robot effect"
        case .arcade: return "Arcade effect"
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
        case .cute:   return 0.072
        case .calm:   return 0.088
        case .deep:   return 0.096
        case .tiny:   return 0.058
        case .robot:  return 0.064
        case .arcade: return 0.044
        }
    }

    var gapDuration: Double {
        switch self {
        case .calm, .deep: return 0.018
        case .arcade: return 0.010
        default: return 0.014
        }
    }

    var pitchJitterHz: Double {
        switch self {
        case .calm, .deep: return 8
        case .robot: return 10
        case .arcade: return 22
        default: return 12
        }
    }

    var waveform: AnimaleseWaveform {
        switch self {
        case .robot: return .squareSoft
        case .arcade: return .sine
        default: return .triangle
        }
    }
}

struct AnimaleseConfig: Sendable {
    var sampleRate: Double = 44100
    var baseFrequency: Double = 470
    var pitchJitterHz: Double = 12
    var charDuration: Double = 0.072
    var gapDuration: Double = 0.014
    var attack: Double = 0.004
    var release: Double = 0.020
    var waveform: AnimaleseWaveform = .triangle
    var speed: Double = 1.0
    var voiceProfile: AnimaleseVoiceProfile = .cute

    static func from(profile: AnimaleseVoiceProfile, speed: Double = 1.0) -> AnimaleseConfig {
        AnimaleseConfig(
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

struct AnimaleseSyllableFrame: Sendable {
    let char: Character
    let parts: KoreanSyllableParts
    let baseFrequency: Double
    let vowelColor: AnimaleseVowelColor
    let consonantTransient: AnimaleseTransientKind
    let finalTail: AnimaleseTailKind
    let duration: Double
    let gap: Double
    let phrasePosition: AnimalesePhrasePosition
}

enum AnimaleseVowelColor: Sendable {
    case bright
    case neutral
    case round
    case dark
    case narrow
}

enum AnimaleseTransientKind: Sendable {
    case none
    case softClick
    case noiseTap
    case pluck
    case breath
}

enum AnimaleseTailKind: Sendable {
    case none
    case shortCut
    case nasalHum
    case softStop
}

enum AnimalesePhrasePosition: Sendable {
    case start
    case middle
    case endFalling
    case endRising
}

enum AnimaleseToken: Sendable {
    case syllable(Character)
    case shortPause
    case mediumPause
    case longPause(ending: AnimalesePhrasePosition)
}

// MARK: - Synthesizer

enum AnimaleseSynthesizer {

    static func synthesize(text: String, config: AnimaleseConfig) -> [Float] {
        let tokens = tokenize(text)
        let syllableCount = tokens.reduce(0) { total, token in
            if case .syllable = token { return total + 1 }
            return total
        }
        guard syllableCount > 0 else { return [] }

        var output: [Float] = []
        var syllableIndex = 0
        var nextPosition: AnimalesePhrasePosition = .start

        for (tokenIndex, token) in tokens.enumerated() {
            switch token {
            case .syllable(let char):
                let terminalPosition = terminalPhrasePosition(after: tokenIndex, in: tokens)
                let phrasePosition = terminalPosition ?? nextPosition
                nextPosition = .middle

                let parts = KoreanSyllableDecomposer.decompose(char)
                let frame = AnimaleseSyllableFrame(
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
                output.append(contentsOf: silence(duration: frame.gap * 0.45, sampleRate: config.sampleRate))
                syllableIndex += 1

            case .shortPause:
                output.append(contentsOf: silence(duration: 0.025 / max(0.25, config.speed), sampleRate: config.sampleRate))
                nextPosition = .start

            case .mediumPause:
                output.append(contentsOf: silence(duration: 0.070 / max(0.25, config.speed), sampleRate: config.sampleRate))
                nextPosition = .start

            case .longPause(let ending):
                output.append(contentsOf: silence(duration: 0.140 / max(0.25, config.speed), sampleRate: config.sampleRate))
                nextPosition = ending == .endRising ? .start : .start
            }
        }

        output.append(contentsOf: silence(duration: 0.055, sampleRate: config.sampleRate))
        return output
    }

    static func vowelColor(for medialIndex: Int?) -> AnimaleseVowelColor {
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

    static func transientKind(for initialIndex: Int?) -> AnimaleseTransientKind {
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

    static func tailKind(for finalIndex: Int?) -> AnimaleseTailKind {
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
        for frame: AnimaleseSyllableFrame,
        config: AnimaleseConfig,
        index: Int,
        total: Int
    ) -> Double {
        let vowelOffset: Double
        switch frame.vowelColor {
        case .bright: vowelOffset = 35
        case .round: vowelOffset = 10
        case .neutral: vowelOffset = 0
        case .dark: vowelOffset = -25
        case .narrow: vowelOffset = 20
        }

        let phraseOffset: Double
        switch frame.phrasePosition {
        case .start: phraseOffset = 15
        case .middle: phraseOffset = 0
        case .endFalling: phraseOffset = -40
        case .endRising: phraseOffset = 45
        }

        let progress = total > 1 ? Double(index) / Double(total - 1) : 0
        let contour = (0.5 - progress) * 18.0
        let jitter = deterministicJitter(for: frame.char, index: index, range: config.pitchJitterHz)
        let frequency = config.baseFrequency + vowelOffset + phraseOffset + contour + jitter
        return min(config.baseFrequency * 1.35, max(config.baseFrequency * 0.75, frequency))
    }

    static func generateSyllable(
        frame: AnimaleseSyllableFrame,
        config: AnimaleseConfig,
        index: Int,
        total: Int
    ) -> [Float] {
        let frequency = speechFrequency(for: frame, config: config, index: index, total: total)
        let duration = frame.finalTail == .shortCut ? frame.duration * 0.88 : frame.duration
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

    private static func tokenize(_ text: String) -> [AnimaleseToken] {
        var tokens: [AnimaleseToken] = []
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

    private static func terminalPhrasePosition(after tokenIndex: Int, in tokens: [AnimaleseToken]) -> AnimalesePhrasePosition? {
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
        kind: AnimaleseTransientKind,
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
        frame: AnimaleseSyllableFrame,
        frequency: Double,
        duration: Double,
        config: AnimaleseConfig
    ) -> [Float] {
        let count = max(1, Int(duration * config.sampleRate))
        let amplitude = config.voiceProfile.isEffectProfile ? 0.34 : 0.42

        return (0..<count).map { i in
            let t = Double(i) / config.sampleRate
            let raw = oscillatorMix(t: t, frequency: frequency, vowelColor: frame.vowelColor, waveform: config.waveform)
            let envelope = vowelEnvelope(sample: i, count: count)
            return Float(raw * envelope * amplitude)
        }
    }

    private static func generateTail(
        kind: AnimaleseTailKind,
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
        vowelColor: AnimaleseVowelColor,
        waveform: AnimaleseWaveform
    ) -> Double {
        let base = baseWave(t: t, frequency: frequency, waveform: waveform)
        let second = sin(2.0 * .pi * frequency * 2.0 * t)
        let low = sin(2.0 * .pi * frequency * 0.5 * t)
        let high = sin(2.0 * .pi * frequency * 3.0 * t)

        switch vowelColor {
        case .bright:
            return base * 0.82 + second * 0.16 + high * 0.02
        case .round:
            return base * 0.76 + low * 0.20 + second * 0.04
        case .neutral:
            return base * 0.90 + second * 0.10
        case .dark:
            return base * 0.68 + low * 0.28 + second * 0.04
        case .narrow:
            return base * 0.80 + second * 0.08 + high * 0.12
        }
    }

    private static func baseWave(t: Double, frequency: Double, waveform: AnimaleseWaveform) -> Double {
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

    private static func transientDuration(for kind: AnimaleseTransientKind) -> Double {
        switch kind {
        case .none: return 0
        case .softClick: return 0.005
        case .noiseTap: return 0.008
        case .pluck: return 0.010
        case .breath: return 0.012
        }
    }

    private static func tailDuration(for kind: AnimaleseTailKind) -> Double {
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
