import Foundation

// MARK: - SupertonicSpeedProbe
// Round 261TTS-SPEED-PROBE-AND-ANIMALESE
//
// Speed 적용 계측: Supertonic3 합성 duration이 speed에 따라 실제로 변하는지 확인.
// 재생 없이 순수 계측만 수행. WAV 저장 없음.
//
// 기대 결과:
//   S 0.70 durationSec > S 1.00 durationSec > S 1.30 durationSec > S 2.00 durationSec
// 이 순서가 깨지면 speed 적용 의심.

// MARK: - SupertonicSpeedProbeResult

struct SupertonicSpeedProbeResult: Identifiable, Sendable {
    let id: UUID
    let preset: String
    let speed: Float
    let text: String
    let durationSec: Double
    let sampleRate: Int
    let sampleCount: Int
    let elapsedMs: Double
    let realtimeFactor: Double

    init(
        preset: String,
        speed: Float,
        text: String,
        durationSec: Double,
        sampleRate: Int,
        sampleCount: Int,
        elapsedMs: Double,
        realtimeFactor: Double
    ) {
        self.id = UUID()
        self.preset = preset
        self.speed = speed
        self.text = text
        self.durationSec = durationSec
        self.sampleRate = sampleRate
        self.sampleCount = sampleCount
        self.elapsedMs = elapsedMs
        self.realtimeFactor = realtimeFactor
    }

    /// duration이 속도 증가에 따라 실제로 감소하고 있는지 단독 판단.
    /// 전체 비교는 SupertonicSpeedProbe.verifyOrdering 사용.
    var verdictLabel: String {
        "S \(String(format: "%.2f", speed))"
    }

    var durationDisplay: String {
        String(format: "%.3fs", durationSec)
    }

    var rtfDisplay: String {
        String(format: "%.2f", realtimeFactor)
    }
}

// MARK: - SupertonicSpeedProbe

enum SupertonicSpeedProbe {

    /// 계측 기준 속도. 0.70 → 1.00 → 1.30 → 2.00 순서.
    static let testSpeeds: [Float] = [0.70, 1.00, 1.30, 2.00]

    /// duration 순서 검증.
    /// 기대: speed가 높을수록 durationSec이 짧아야 함.
    /// - Returns: true이면 speed 적용됨, false이면 의심.
    static func verifyOrdering(_ results: [SupertonicSpeedProbeResult]) -> Bool {
        guard results.count >= 2 else { return false }
        let sorted = results.sorted { $0.speed < $1.speed }
        for i in 1..<sorted.count {
            if sorted[i].durationSec >= sorted[i - 1].durationSec {
                return false
            }
        }
        return true
    }

    /// 전체 결과에 대한 판정 문자열.
    static func verdictSummary(_ results: [SupertonicSpeedProbeResult]) -> String {
        guard !results.isEmpty else { return "결과 없음" }
        if verifyOrdering(results) {
            return "✅ Speed 적용됨 — duration이 속도 증가에 따라 감소"
        } else {
            return "⚠️ Speed 의심 — duration 순서가 기대와 다름"
        }
    }
}
