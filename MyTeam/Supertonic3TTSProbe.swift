import Foundation

// MARK: - Supertonic3 Readiness Enum

enum Supertonic3Readiness: String, Codable, Sendable {
    case disabled
    case missingModel
    case runtimeUnavailable
    case readyForInference
}

// MARK: - Supertonic3 Probe Result

struct Supertonic3ProbeResult: Sendable {
    let enabled: Bool
    let modelCheck: Supertonic3ModelLocator.ModelCheckResult
    let runtimeAvailability: ONNXRuntimeAvailability
    let selectedPreset: String
    let selectedLanguage: String
    let readiness: Supertonic3Readiness
    let redactedModelPath: String

    var canSynthesize: Bool {
        readiness == .readyForInference
    }

    var statusMessage: String {
        switch readiness {
        case .disabled:
            return "Supertonic3 비활성화"
        case .missingModel:
            return "모델 파일 누락: \(modelCheck.missingFiles.joined(separator: ", "))"
        case .runtimeUnavailable:
            return "ONNX Runtime 미탑재 (Mac local에서 필요)"
        case .readyForInference:
            return "사용 가능 (\(redactedModelPath))"
        }
    }
}

// MARK: - Supertonic3ProbeRunResult (legacy, for compatibility)

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

    /// Round 248TTS-A: 런타임 readiness probe (inference 없음)
    /// 모델 파일, 런타임 상태, 설정을 점검하고 readiness enum 반환
    static func probe() -> Supertonic3ProbeResult {
        let modelCheck = Supertonic3ModelLocator.checkModel()
        let adapter = ONNXRuntimeUnavailableAdapter()
        let runtimeAvailability = adapter.availability()

        // Determine readiness state
        let enabled = Supertonic3TTSConfig.isEnabled
        let readiness: Supertonic3Readiness
        if !enabled {
            readiness = .disabled
        } else if !modelCheck.isAvailable {
            readiness = .missingModel
        } else if runtimeAvailability == .unavailable {
            readiness = .runtimeUnavailable
        } else {
            readiness = .readyForInference
        }

        return Supertonic3ProbeResult(
            enabled: enabled,
            modelCheck: modelCheck,
            runtimeAvailability: runtimeAvailability,
            selectedPreset: Supertonic3TTSConfig.selectedVoicePreset,
            selectedLanguage: Supertonic3TTSConfig.selectedLanguage,
            readiness: readiness,
            redactedModelPath: modelCheck.redactedDirectory
        )
    }

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
