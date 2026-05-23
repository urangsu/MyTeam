import Foundation

// MARK: - AnimaleseSynthesizer
// Round 261TTS-SPEED-PROBE-AND-ANIMALESE
//
// Procedural blip speech — 글자/음절 단위 파형을 생성하는 동물의숲식 말소리 엔진.
//
// 원칙:
//   - Nintendo/Animal Crossing 원본 사운드 샘플 사용 금지.
//   - YouTube 오디오 추출 금지.
//   - 자체 sine/triangle/squareSoft/noiseBlend 파형만 사용.
//   - Supertonic3ONNXRunner 완전 독립. 모델 없어도 동작.
//   - TTS Lab 테스트 전용. 기본 채팅 발화에 사용하지 않음.
//
// 동작:
//   - 한글/영문/숫자: 각 문자를 blip 1개로 변환.
//   - 공백/구두점: gap으로 처리.
//   - 각 blip은 짧은 ADSR envelope를 씌워 click 방지.
//   - speed > 1.0이면 charDuration/gapDuration을 단축.

// MARK: - AnimaleseWaveform

enum AnimaleseWaveform: String, CaseIterable, Sendable {
    case sine        // 부드러운 순수음
    case triangle    // 부드럽고 약간 하드 (AC 느낌에 가까움)
    case squareSoft  // 부드러운 사각파 — 로봇/픽셀 느낌
    case noiseBlend  // sine + 소량 화이트노이즈 혼합 (독특한 질감)

    var displayName: String {
        switch self {
        case .sine:       return "Sine — 부드러운 순음"
        case .triangle:   return "Triangle — AC 느낌"
        case .squareSoft: return "Square(soft) — 픽셀/로봇"
        case .noiseBlend: return "NoiseBlend — 독특한 질감"
        }
    }
}

// MARK: - AnimaleseVoiceProfile

enum AnimaleseVoiceProfile: String, CaseIterable, Sendable, Identifiable {
    case cute
    case calm
    case deep
    case robot
    case tiny

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cute:  return "Cute 🌸"
        case .calm:  return "Calm 🌊"
        case .deep:  return "Deep 🌲"
        case .robot: return "Robot 🤖"
        case .tiny:  return "Tiny ✨"
        }
    }

    var baseFrequency: Double {
        switch self {
        case .cute:  return 620
        case .calm:  return 430
        case .deep:  return 300
        case .robot: return 520
        case .tiny:  return 760
        }
    }

    var charDuration: Double {
        switch self {
        case .cute:  return 0.040
        case .calm:  return 0.055
        case .deep:  return 0.060
        case .robot: return 0.040
        case .tiny:  return 0.035
        }
    }

    var gapDuration: Double { 0.012 }

    var pitchJitter: Double { 90.0 }

    var waveform: AnimaleseWaveform {
        switch self {
        case .robot: return .squareSoft
        case .tiny:  return .sine
        default:     return .triangle
        }
    }
}

// MARK: - AnimaleseConfig

struct AnimaleseConfig: Sendable {
    var sampleRate: Double = 44100
    var baseFrequency: Double = 520
    var pitchJitter: Double = 90
    var charDuration: Double = 0.045
    var gapDuration: Double = 0.012
    var attack: Double = 0.006
    var release: Double = 0.018
    var waveform: AnimaleseWaveform = .triangle
    var speed: Double = 1.0
    var voiceProfile: AnimaleseVoiceProfile = .cute

    /// 프로필 적용 factory.
    static func from(profile: AnimaleseVoiceProfile, speed: Double = 1.0) -> AnimaleseConfig {
        AnimaleseConfig(
            sampleRate:    44100,
            baseFrequency: profile.baseFrequency,
            pitchJitter:   profile.pitchJitter,
            charDuration:  profile.charDuration,
            gapDuration:   profile.gapDuration,
            attack:        0.006,
            release:       0.018,
            waveform:      profile.waveform,
            speed:         speed,
            voiceProfile:  profile
        )
    }

    /// speed 적용 후 실제 charDuration.
    var effectiveCharDuration: Double {
        guard speed > 0 else { return charDuration }
        return charDuration / speed
    }

    /// speed 적용 후 실제 gapDuration.
    var effectiveGapDuration: Double {
        guard speed > 0 else { return gapDuration }
        return gapDuration / speed
    }
}

// MARK: - AnimaleseSynthesizer

enum AnimaleseSynthesizer {

    // MARK: - Public

    /// 텍스트를 PCM Float 배열로 변환한다.
    /// 44100Hz mono. 재생은 AudioPlaybackService에 위임.
    static func synthesize(text: String, config: AnimaleseConfig) -> [Float] {
        let sr = config.sampleRate
        var output: [Float] = []

        for (i, char) in text.enumerated() {
            if char.isWhitespace || isPunctuation(char) {
                // 공백/구두점 → gap
                let gapSamples = Int(config.effectiveGapDuration * sr)
                output.append(contentsOf: [Float](repeating: 0, count: max(1, gapSamples)))
            } else if isVoicedChar(char) {
                // 발음 문자 → blip
                let freq = frequency(for: char, config: config, index: i)
                let blip = generateBlip(
                    frequency: freq,
                    duration: config.effectiveCharDuration,
                    attack:   config.attack,
                    release:  config.release,
                    sampleRate: sr,
                    waveform:  config.waveform
                )
                output.append(contentsOf: blip)

                // 글자 사이 미니 갭 (click 방지)
                let miniGap = Int(0.003 * sr)
                output.append(contentsOf: [Float](repeating: 0, count: miniGap))
            }
        }

        // 무음 패딩 (플레이어 끊김 방지)
        let tailPad = Int(0.05 * sr)
        output.append(contentsOf: [Float](repeating: 0, count: tailPad))

        return output
    }

    // MARK: - Frequency Mapping

    /// 문자별 pitch 결정.
    /// 같은 글자는 같은 pitch, index 기반 작은 jitter 추가.
    static func frequency(for char: Character, config: AnimaleseConfig, index: Int) -> Double {
        let scalarValue = char.unicodeScalars.first?.value ?? 65

        // 12음 스케일 degree (major scale)
        let majorScale: [Double] = [0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19]
        let degree = majorScale[Int(scalarValue % UInt32(majorScale.count))]
        let baseFreq = config.baseFrequency * pow(2.0, degree / 12.0)

        // index 기반 작은 jitter (같은 글자라도 연속할 때 약간 달라짐)
        let jitterSeed = Double((scalarValue &+ UInt32(index &* 7)) % 17)
        let jitterRange = config.pitchJitter / 2.0
        let jitter = (jitterSeed / 17.0 - 0.5) * jitterRange

        return max(80, baseFreq + jitter)
    }

    // MARK: - Blip Generation

    private static func generateBlip(
        frequency: Double,
        duration: Double,
        attack: Double,
        release: Double,
        sampleRate: Double,
        waveform: AnimaleseWaveform
    ) -> [Float] {
        let totalSamples = Int(duration * sampleRate)
        guard totalSamples > 0 else { return [] }

        let attackSamples  = min(Int(attack * sampleRate), totalSamples / 4)
        let releaseSamples = min(Int(release * sampleRate), totalSamples / 3)
        let sustainSamples = max(0, totalSamples - attackSamples - releaseSamples)

        var result = [Float](repeating: 0, count: totalSamples)

        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            let raw = sampleValue(t: t, freq: frequency, waveform: waveform)

            // ADSR envelope
            let envelope: Double
            if i < attackSamples {
                envelope = Double(i) / Double(max(1, attackSamples))
            } else if i < attackSamples + sustainSamples {
                envelope = 1.0
            } else {
                let releasePos = i - attackSamples - sustainSamples
                envelope = 1.0 - Double(releasePos) / Double(max(1, releaseSamples))
            }

            result[i] = Float(raw * max(0, min(1, envelope)) * 0.55)
        }

        return result
    }

    private static func sampleValue(t: Double, freq: Double, waveform: AnimaleseWaveform) -> Double {
        let phase = (t * freq).truncatingRemainder(dividingBy: 1.0)
        switch waveform {
        case .sine:
            return sin(2.0 * .pi * phase)

        case .triangle:
            return phase < 0.5 ? 4.0 * phase - 1.0 : 3.0 - 4.0 * phase

        case .squareSoft:
            // duty 50% square, softened with tanh
            let raw = phase < 0.5 ? 1.0 : -1.0
            return tanh(raw * 3.0)

        case .noiseBlend:
            // sine + 15% noise
            let s = sin(2.0 * .pi * phase)
            let noise = Double.random(in: -1.0...1.0) * 0.15
            return (s * 0.85 + noise) / 1.0
        }
    }

    // MARK: - Character Classification

    private static func isVoicedChar(_ c: Character) -> Bool {
        guard let scalar = c.unicodeScalars.first else { return false }
        let v = scalar.value
        // 한글 음절: AC00–D7A3
        if v >= 0xAC00 && v <= 0xD7A3 { return true }
        // 한글 자모: 1100–11FF, 3130–318F
        if v >= 0x1100 && v <= 0x11FF { return true }
        if v >= 0x3130 && v <= 0x318F { return true }
        // 영문, 숫자
        return c.isLetter || c.isNumber
    }

    private static func isPunctuation(_ c: Character) -> Bool {
        c.isPunctuation || c.isSymbol
    }
}
