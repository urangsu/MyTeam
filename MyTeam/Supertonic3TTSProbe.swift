import Foundation

// MARK: - Supertonic3TTSProbe
// Round 247TTS-SUPERTONIC3-POC: 런타임 probe (Cloud: info-only, Mac: model 검사).
//
// Cloud 환경: ONNX Runtime 없음 → runtimeAvailable = false
// Mac 환경(248TTS): ONNX Runtime 존재 여부 실제 검사로 교체 예정

// MARK: - Supertonic3ProbeRunResult

struct Supertonic3ProbeRunResult: Sendable {
    let timestamp: Date
    let modelCheck: Supertonic3ModelLocator.ModelCheckResult
    let isConfigEnabled: Bool
    let runtimeAvailable: Bool
    let runtimeNote: String
    let selectedPreset: String
    let availablePresets: [String]
    let outputSampleRate: Int
    let licenseStatus: String
    let isLicenseVerifiedForAppStore: Bool

    var canSynthesize: Bool {
        isConfigEnabled && modelCheck.isAvailable && runtimeAvailable
    }

    var readySummary: String {
        if canSynthesize {
            return "Supertonic3 TTS: 사용 가능"
        } else {
            var reasons: [String] = []
            if !isConfigEnabled { reasons.append("비활성화됨") }
            if !modelCheck.isAvailable { reasons.append("모델 없음 (\(modelCheck.missingFiles.joined(separator: ", ")))") }
            if !runtimeAvailable { reasons.append("ONNX Runtime 미탑재") }
            return "Supertonic3 TTS: 사용 불가 — \(reasons.joined(separator: ", "))"
        }
    }

    var detailedLines: [String] {
        [
            "[Supertonic3 Probe @ \(ISO8601DateFormatter().string(from: timestamp))]",
            "enabled:         \(isConfigEnabled)",
            "model:           \(modelCheck.isAvailable ? "ready (\(modelCheck.totalFoundSizeBytes / 1_048_576) MB)" : "missing \(modelCheck.missingFiles)")",
            "runtime:         \(runtimeAvailable ? "available" : "unavailable — \(runtimeNote)")",
            "preset:          \(selectedPreset) (available: \(availablePresets.joined(separator: ", ")))",
            "outputRate:      \(outputSampleRate) Hz",
            "license:         \(licenseStatus)",
            "appStoreVerified: \(isLicenseVerifiedForAppStore)",
            "canSynthesize:   \(canSynthesize)"
        ]
    }

    var detailedSummary: String {
        detailedLines.joined(separator: "\n  ")
    }
}

// MARK: - Supertonic3TTSProbe

enum Supertonic3TTSProbe {

    /// Cloud 환경 probe: 모델 파일 상태 + 설정 정보 수집 (inference 없음)
    /// Mac 248TTS에서: runtimeAvailable을 실제 OrtEnvironment 검사로 교체
    static func run() -> Supertonic3ProbeRunResult {
        let modelCheck = Supertonic3ModelLocator.checkModel()

        return Supertonic3ProbeRunResult(
            timestamp: Date(),
            modelCheck: modelCheck,
            isConfigEnabled: Supertonic3TTSConfig.isEnabled,
            runtimeAvailable: false,  // Cloud: 항상 false. 248TTS(Mac): OrtEnvironment 검사로 교체
            runtimeNote: "ONNX Runtime 미탑재 (248TTS에서 onnxruntime-swift-package-manager SPM 추가 예정)",
            selectedPreset: Supertonic3TTSConfig.selectedVoicePreset,
            availablePresets: Supertonic3TTSConfig.availableVoicePresets,
            outputSampleRate: Supertonic3TTSConfig.outputSampleRate,
            licenseStatus: Supertonic3TTSConfig.licenseStatus,
            isLicenseVerifiedForAppStore: Supertonic3TTSConfig.isLicenseVerifiedForAppStore
        )
    }

    /// 빠른 상태 요약 문자열 (로그/진단용)
    static func quickStatus() -> String {
        run().readySummary
    }
}
