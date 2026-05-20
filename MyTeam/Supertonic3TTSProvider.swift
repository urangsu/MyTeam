import Foundation

// MARK: - Supertonic3TTSProvider
// Round 247TTS-SUPERTONIC3-POC: Supertonic3 provider skeleton.
//
// Cloud 라운드 구현 범위:
// - interface + error type 정의
// - synthesize(): 항상 throws .missingRuntime
// - 실제 ONNX Runtime 통합은 248TTS (Mac local)에서 진행
//   → SPM 의존성: onnxruntime-swift-package-manager (Microsoft, v1.16.0+)
//
// Mac 구현 TODO (248TTS):
// - Package.swift에 .package(url: "https://github.com/microsoft/onnxruntime-swift-package-manager", ...)
// - OrtEnvironment, OrtSession, OrtValue 사용
// - 44.1kHz WAV 출력 → AudioPlaybackService용 24kHz 변환

// MARK: - Supertonic3TTSError

enum Supertonic3TTSError: Error, Sendable {
    case missingRuntime              // Cloud 환경 — ONNX Runtime 미탑재
    case missingModel(files: [String])
    case notEnabled                  // isEnabled == false
    case inferenceError(String)
    case audioConversionError
    case invalidVoicePreset(String)
}

// MARK: - Supertonic3TTSProvider

/// Supertonic3 TTS provider.
/// 이번 라운드(247TTS): skeleton — synthesize()는 항상 .missingRuntime
/// 다음 라운드(248TTS): 실제 ONNX inference 연결
actor Supertonic3TTSProvider {
    static let shared = Supertonic3TTSProvider()
    private init() {}

    // MARK: - Availability

    nonisolated func isConfigEnabled() -> Bool {
        Supertonic3TTSConfig.isEnabled
    }

    nonisolated func isModelAvailable() -> Bool {
        Supertonic3ModelLocator.isModelAvailable()
    }

    /// provider를 실제로 사용할 수 있는지 확인
    nonisolated func canSynthesize() -> Bool {
        isConfigEnabled() && isModelAvailable()
    }

    // MARK: - Synthesis (skeleton)

    /// TTS 합성. Cloud 환경에서는 항상 .missingRuntime을 throw.
    /// Mac 환경에서도 248TTS 전까지는 동일하게 동작.
    ///
    /// - Parameters:
    ///   - text: 합성할 텍스트
    ///   - voicePreset: 음성 프리셋 ID (M1–M5, F1–F5)
    /// - Returns: TTSOutput (Mac 구현 후 실제 WAV 경로 포함)
    func synthesize(text: String, voicePreset: String? = nil) async throws -> TTSOutput {
        guard Supertonic3TTSConfig.isEnabled else {
            throw Supertonic3TTSError.notEnabled
        }

        let modelCheck = Supertonic3ModelLocator.checkModel()
        guard modelCheck.isAvailable else {
            throw Supertonic3TTSError.missingModel(files: modelCheck.missingFiles)
        }

        let preset = voicePreset ?? Supertonic3TTSConfig.selectedVoicePreset
        guard Supertonic3TTSConfig.availableVoicePresets.contains(preset) else {
            throw Supertonic3TTSError.invalidVoicePreset(preset)
        }

        // Cloud / 248TTS 전: ONNX Runtime 없음
        // Mac 구현 TODO:
        //   let env = try OrtEnvironment.shared()
        //   let session = try OrtSession(env: env, modelPath: modelPath, sessionOptions: nil)
        //   ... 4-stage inference (text_encoder → duration_predictor → vector_estimator → vocoder)
        throw Supertonic3TTSError.missingRuntime
    }

    // MARK: - Probe

    /// 모델 파일 상태 점검 (inference 없이)
    func probe() -> Supertonic3ProbeResult {
        let modelCheck = Supertonic3ModelLocator.checkModel()
        return Supertonic3ProbeResult(
            modelCheck: modelCheck,
            isEnabled: Supertonic3TTSConfig.isEnabled,
            selectedPreset: Supertonic3TTSConfig.selectedVoicePreset,
            runtimeAvailable: false,  // Cloud: false. Mac 248TTS: ONNX Runtime 검사로 교체
            runtimeNote: "ONNX Runtime 미탑재 (248TTS에서 SPM 추가 예정)"
        )
    }
}

// MARK: - Supertonic3ProbeResult

struct Supertonic3ProbeResult: Sendable {
    let modelCheck: Supertonic3ModelLocator.ModelCheckResult
    let isEnabled: Bool
    let selectedPreset: String
    let runtimeAvailable: Bool
    let runtimeNote: String

    var summary: String {
        var lines: [String] = ["[Supertonic3 Probe]"]
        lines.append("enabled: \(isEnabled)")
        lines.append("model: \(modelCheck.isAvailable ? "available" : "missing (\(modelCheck.missingFiles.joined(separator: ", ")))")")
        lines.append("runtime: \(runtimeAvailable ? "available" : "unavailable — \(runtimeNote)")")
        lines.append("preset: \(selectedPreset)")
        return lines.joined(separator: "\n  ")
    }
}
