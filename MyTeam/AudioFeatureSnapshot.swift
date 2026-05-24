import Foundation

struct AudioFeatureSnapshot: Sendable {
    let durationSec: Double
    let sampleCount: Int
    let sampleRate: Int
    let rms: Double
    let peak: Double
    let zeroCrossingRate: Double
    let estimatedClickCount: Int

    var hasClickWarning: Bool {
        estimatedClickCount > max(3, sampleCount / 18_000)
    }
}

enum AudioFeatureAnalyzer {
    static func analyze(samples: [Float], sampleRate: Int) -> AudioFeatureSnapshot {
        guard !samples.isEmpty, sampleRate > 0 else {
            return AudioFeatureSnapshot(
                durationSec: 0,
                sampleCount: samples.count,
                sampleRate: sampleRate,
                rms: 0,
                peak: 0,
                zeroCrossingRate: 0,
                estimatedClickCount: 0
            )
        }

        var squareSum = 0.0
        var peak = 0.0
        var zeroCrossings = 0
        var estimatedClickCount = 0
        var previous = Double(samples[0])

        for sample in samples {
            let value = Double(sample)
            let absValue = abs(value)
            squareSum += value * value
            peak = max(peak, absValue)

            if (previous < 0 && value >= 0) || (previous >= 0 && value < 0) {
                zeroCrossings += 1
            }
            if abs(value - previous) > 0.8 {
                estimatedClickCount += 1
            }
            previous = value
        }

        let duration = Double(samples.count) / Double(sampleRate)
        let zcr = duration > 0 ? Double(zeroCrossings) / duration : 0
        return AudioFeatureSnapshot(
            durationSec: duration,
            sampleCount: samples.count,
            sampleRate: sampleRate,
            rms: sqrt(squareSum / Double(samples.count)),
            peak: peak,
            zeroCrossingRate: zcr,
            estimatedClickCount: estimatedClickCount
        )
    }
}
