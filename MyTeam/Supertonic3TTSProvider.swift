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
/// Round 247TTS: Cloud skeleton — synthesize()는 항상 .missingRuntime.
/// Round 249TTS: 실제 ONNX inference 연결 (Mac local, SPM 의존성 추가 후).
///
/// 구조 단순화 이유: Cloud 환경에서 ONNX Runtime 미탑재.
/// isEnabled/checkModel 등 Config/Locator 호출은 249TTS에서 actor context 정리 후 연결.
actor Supertonic3TTSProvider {
    static let shared = Supertonic3TTSProvider()
    private init() {}

    // MARK: - Synthesis

    /// TTS 합성.
    /// Cloud 구현: 항상 .missingRuntime. ONNX Runtime 미탑재.
    /// Mac 구현 TODO (249TTS): ONNX Runtime SPM 추가 후 실제 inference 연결.
    func synthesize(text: String, voicePreset: String? = nil) async throws -> TTSOutput {
        // Cloud skeleton: ONNX Runtime not available. Always throws.
        // 249TTS(Mac): guard isEnabled, checkModel, validate preset, run pipeline.
        throw TTSProviderError.missingRuntime
    }
}
