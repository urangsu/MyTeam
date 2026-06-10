import Foundation

// MARK: - Supertonic3 Readiness Enum

enum Supertonic3Readiness: String, Codable, Sendable {
    case disabled
    case missingModel
    case runtimeUnavailable
    case noticeRequired        // Runtime linked, model ready, but notice not accepted
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
        case .noticeRequired:
            return "고지 수락 필요 — Supertonic 사용 고지를 확인하세요"
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
    let noticeAccepted: Bool          // Round 254TTS-PROBE-FIX
    let selectedPreset: String
    let availablePresets: [String]
    let outputSampleRate: Int
    let licenseStatus: String
    let isLicenseVerifiedForAppStore: Bool

    /// canSynthesize: enabled + model ready + runtime linked + notice accepted
    var canSynthesize: Bool {
        isConfigEnabled && modelCheck.isAvailable && runtimeAvailable && noticeAccepted
    }

    var readySummary: String {
        if canSynthesize {
            return "Supertonic3 TTS: 사용 가능"
        } else {
            var reasons: [String] = []
            if !isConfigEnabled { reasons.append("비활성화됨") }
            if !modelCheck.isAvailable { reasons.append("모델 없음 (\(modelCheck.missingFiles.joined(separator: ", ")))") }
            if !runtimeAvailable { reasons.append("ONNX Runtime 미탑재") }
            if !noticeAccepted { reasons.append("고지 수락 필요") }
            return "Supertonic3 TTS: 사용 불가 — \(reasons.joined(separator: ", "))"
        }
    }

    var detailedLines: [String] {
        [
            "[Supertonic3 Probe @ \(ISO8601DateFormatter().string(from: timestamp))]",
            "enabled:         \(isConfigEnabled)",
            "model:           \(modelCheck.isAvailable ? "ready (\(modelCheck.totalFoundSizeBytes / 1_048_576) MB)" : "missing \(modelCheck.missingFiles)")",
            "runtime:         \(runtimeAvailable ? "linked — \(runtimeNote)" : "unavailable — \(runtimeNote)")",
            "noticeAccepted:  \(noticeAccepted)",
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

    /// Round 254TTS-PROBE-FIX: 런타임 readiness probe (inference 없음)
    /// 모델 파일 + runtime binding + notice 상태를 점검하고 readiness enum 반환.
    static func probe() -> Supertonic3ProbeResult {
        let modelCheck = Supertonic3ModelLocator.checkModel()
        let enabled = Supertonic3TTSConfig.isEnabled
        let runtimeLinked = Supertonic3ONNXRuntimeProbe.isRuntimeLinked
        let noticeAccepted = SupertonicTTSNoticePolicy.isCurrentNoticeAccepted
        let distributionAllowed = Supertonic3DistributionGate.isRuntimeAllowed

        let runtimeAvailability: ONNXRuntimeAvailability
        if runtimeLinked {
            runtimeAvailability = noticeAccepted ? .runtimeReady : .noticeRequired
        } else {
            runtimeAvailability = .unavailable
        }

        let readiness: Supertonic3Readiness
        if !enabled {
            readiness = .disabled
        } else if !distributionAllowed {
            readiness = .runtimeUnavailable
        } else if !modelCheck.isAvailable {
            readiness = .missingModel
        } else if !runtimeLinked {
            readiness = .runtimeUnavailable
        } else if !noticeAccepted {
            readiness = .noticeRequired
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

    /// Round 254TTS-PROBE-FIX: probe + run 결과 통합 (inference 없음)
    /// runtimeAvailable: ORTEnv 생성 가능 여부 (실제 합성 성공 보장 아님)
    static func run() -> Supertonic3ProbeRunResult {
        let modelCheck = Supertonic3ModelLocator.checkModel()
        let runtimeLinked = Supertonic3ONNXRuntimeProbe.isRuntimeLinked
        let noticeAccepted = SupertonicTTSNoticePolicy.isCurrentNoticeAccepted

        return Supertonic3ProbeRunResult(
            timestamp: Date(),
            modelCheck: modelCheck,
            isConfigEnabled: Supertonic3TTSConfig.isEnabled,
            runtimeAvailable: runtimeLinked,
            runtimeNote: Supertonic3ONNXRuntimeProbe.statusNote,
            noticeAccepted: noticeAccepted,
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
