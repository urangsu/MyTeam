import Foundation

nonisolated struct AudioFeatureSnapshot: Sendable, Equatable {
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

nonisolated enum AudioPlaybackRejection: String, Sendable, Equatable {
    case empty
    case invalidSampleRate
    case nonFinite
    case silent
    case peakOutOfRange
}

nonisolated enum AudioPlaybackQualityResult: Sendable, Equatable {
    case accepted(AudioFeatureSnapshot)
    case rejected(AudioPlaybackRejection)
}

nonisolated enum AudioPlaybackQualityPolicy {
    static func validate(samples: [Float], sampleRate: Int) -> AudioPlaybackQualityResult {
        guard !samples.isEmpty else { return .rejected(.empty) }
        guard (8_000...192_000).contains(sampleRate) else { return .rejected(.invalidSampleRate) }
        guard samples.allSatisfy(\.isFinite) else { return .rejected(.nonFinite) }

        let snapshot = AudioFeatureAnalyzer.analyze(samples: samples, sampleRate: sampleRate)
        guard snapshot.peak >= 0.0005, snapshot.rms >= 0.0001 else {
            return .rejected(.silent)
        }
        guard snapshot.peak <= 1.05 else {
            return .rejected(.peakOutOfRange)
        }
        return .accepted(snapshot)
    }
}

nonisolated enum AudioFeatureAnalyzer {
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
