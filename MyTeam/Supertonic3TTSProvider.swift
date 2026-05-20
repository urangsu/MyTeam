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

    // MARK: - Synthesis

    /// TTS 합성 (pipeline 기반).
    /// - Checks config enabled
    /// - Validates model availability
    /// - Validates voice preset
    /// - Delegates to Supertonic3InferencePipeline
    ///
    /// - Parameters:
    ///   - text: 합성할 텍스트
    ///   - voicePreset: 음성 프리셋 ID (M1–M5, F1–F5)
    /// - Returns: TTSOutput
    /// - Throws: TTSProviderError for various failure modes
    func synthesize(text: String, voicePreset: String? = nil) async throws -> TTSOutput {
        // Step 1: Check provider is enabled
        guard Supertonic3TTSConfig.isEnabled else {
            throw TTSProviderError.notEnabled
        }

        // Step 2: Check model files exist
        let modelCheck = Supertonic3ModelLocator.checkModel()
        guard modelCheck.isAvailable else {
            throw TTSProviderError.missingModel
        }

        // Step 3: Validate voice preset
        let preset = voicePreset ?? Supertonic3TTSConfig.selectedVoicePreset
        guard Supertonic3TTSConfig.availableVoicePresets.contains(preset) else {
            throw TTSProviderError.invalidVoicePreset(preset)
        }

        // Step 4: Delegate to inference pipeline
        let pipeline = Supertonic3InferencePipeline()
        let result = try await pipeline.synthesize(
            text: text,
            preset: preset,
            languageCode: Supertonic3TTSConfig.selectedLanguage,
            modelDirectory: modelCheck.directoryURL
        )

        return result
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
