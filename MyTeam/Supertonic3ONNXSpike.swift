import Foundation

// MARK: - Supertonic3ONNXSpike
// Round 249TTS-SPIKE: Product readiness gate for Supertonic3 ONNX integration.
//
// All readiness flags are false until explicitly verified on Mac local build.
// This struct prevents accidental promotion to production surfaces.
//
// Policy:
//   - main product surface: TTS 노출 금지
//   - SystemTTS fallback: 부활 금지
//   - auto-init on launch: 금지
//   - model bundled in app: 금지
//   - production-ready 표현: 금지

struct SupertonicProductReadiness: Sendable {

    // MARK: - Gate flags (all false — spike scope only)

    /// True only after: ONNX pipeline builds without errors on Mac.
    /// Requires: onnxruntime_objc import resolves, OrtSession/OrtValue API compiles.
    let onnxSwiftBuildVerified: Bool = false

    /// True only after: actual synthesis run completes (non-throw) on Mac with real models.
    let synthesisRunSucceeded: Bool = false

    /// True only after: RTF measured < 0.5x on target device.
    /// Target from Python SDK: RTF 0.012–0.015x on M4 Pro (i.e. 100x realtime).
    let realtimeFactor: Double? = nil
    let rtfAcceptable: Bool = false

    /// True only after: audio quality verified (human listening test on Mac).
    let audioQualityVerified: Bool = false

    /// True only after: App Store license review for OpenRAIL-M completed.
    let licenseVerifiedForAppStore: Bool = false

    /// True only after: model bundling strategy decided (download flow, size impact).
    let distributionStrategyDecided: Bool = false

    // MARK: - Production gate

    /// Production usage is allowed only when ALL flags are true.
    /// Currently always false (spike round).
    var isProductionReady: Bool {
        onnxSwiftBuildVerified
            && synthesisRunSucceeded
            && rtfAcceptable
            && audioQualityVerified
            && licenseVerifiedForAppStore
            && distributionStrategyDecided
    }

    // MARK: - Summary

    var summary: String {
        """
        Supertonic3 ONNX Spike Readiness (Round 249TTS):
          Swift build verified:         \(onnxSwiftBuildVerified ? "✅" : "⬜")
          Synthesis run succeeded:      \(synthesisRunSucceeded ? "✅" : "⬜")
          RTF acceptable:               \(rtfAcceptable ? "✅" : "⬜")\(realtimeFactor.map { String(format: " (%.3fx)", $0) } ?? "")
          Audio quality verified:       \(audioQualityVerified ? "✅" : "⬜")
          License for App Store:        \(licenseVerifiedForAppStore ? "✅" : "⬜")
          Distribution strategy:        \(distributionStrategyDecided ? "✅" : "⬜")
          PRODUCTION READY:             \(isProductionReady ? "✅ YES" : "❌ NOT YET")
        """
    }
}

// MARK: - Spike metadata

enum Supertonic3SpikeMeta {
    static let spikeRound = "249TTS-SPIKE"
    static let spikeBranch = "spike/supertonic3-onnx-swift"
    static let spikeDate = "2026-05-21"
    static let scope = "Developer Lab only — Supertonic3 ONNX Swift feasibility"
    static let policyViolations: [String] = []  // policy checks live in ToolContractValidator

    /// Quick check: is the spike runner available in this build?
    /// Always true after 249TTS-SPIKE — runner file exists.
    static let runnerAvailable: Bool = true

    /// Quick check: would auto-init occur on launch?
    /// Always false — no init in AppDelegate, SceneDelegate, or any @main entry point.
    static let autoInitOnLaunch: Bool = false

    /// Quick check: are model files bundled in the app target?
    /// Always false — models stay at ~/.cache/supertonic3/
    static let modelBundled: Bool = false
}
