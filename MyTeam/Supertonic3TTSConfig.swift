import Foundation

// MARK: - Supertonic3TTSConfig
// Round 247TTS-SUPERTONIC3-POC: Supertonic3 provider 설정.
//
// 정책:
// - 기본 비활성화 (isEnabled = UserDefaults bool → false by default)
// - 로컬 모델 필요 (~/.cache/supertonic3/onnx/)
// - 자동 다운로드 절대 없음 — 사용자가 직접 다운로드해야 함
// - HuggingFace: Supertone/supertonic-3 (MIT + OpenRAIL-M)
// - 44.1kHz WAV 출력 — 기존 24kHz AudioPlaybackService와 변환 필요 (248TTS에서 구현)

enum Supertonic3TTSConfig {

    // MARK: - Model Paths

    /// Supertonic3 ONNX 모델 디렉토리 (Python SDK 기본 경로 참조)
    static var modelDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/supertonic3/onnx", isDirectory: true)
    }

    /// Voice style JSON 파일 디렉토리
    static var voiceStylesDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/supertonic3/voice_styles", isDirectory: true)
    }

    // MARK: - Required Model Files

    /// HuggingFace Supertone/supertonic-3 실제 파일명 기반 (2026-05 확인)
    static let requiredModelFiles: [String] = [
        "text_encoder.onnx",       // ~36.4 MB
        "duration_predictor.onnx", // ~3.7 MB
        "vector_estimator.onnx",   // ~257 MB
        "vocoder.onnx"             // ~101 MB
    ]
    // 총 ~398 MB. 번들에 포함하지 않음.

    // MARK: - Voice Presets

    /// HuggingFace Supertone/supertonic-3 voice_styles/ 10개 프리셋
    static let availableVoicePresets: [String] = [
        "M1", "M2", "M3", "M4", "M5",  // 남성 5종
        "F1", "F2", "F3", "F4", "F5"   // 여성 5종
    ]

    static var selectedVoicePreset: String {
        UserDefaults.standard.string(forKey: "supertonic3VoicePreset") ?? "F1"
    }

    // MARK: - Feature Flag

    /// 기본값 false — UserDefaults bool의 기본 반환값이 false이므로 자동으로 off.
    /// Developer Lab에서만 true로 설정 가능.
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "supertonic3ExperimentalEnabled")
    }

    // MARK: - Output Spec

    /// Supertonic3 WAV 출력 샘플레이트 (44.1kHz)
    /// 기존 AudioPlaybackService는 24kHz PCM → 변환 필요 (248TTS에서 구현)
    static let outputSampleRate: Int = 44100
    static let outputBitDepth: Int = 16

    // MARK: - Inference Params

    /// 추론 denoising step 수 (5–12). 낮을수록 빠름, 높을수록 품질 우수.
    /// 기본 8 (품질/속도 균형)
    static var totalStep: Int {
        UserDefaults.standard.integer(forKey: "supertonic3TotalStep") > 0
            ? UserDefaults.standard.integer(forKey: "supertonic3TotalStep")
            : 8
    }

    // MARK: - License / Distribution Policy

    /// MIT (코드) + OpenRAIL-M (모델) — 상업적 사용 허용, 재배포 조건 검토 필요
    /// App Store 번들 허용 여부: 미검증 (248TTS에서 법무 검토 필요)
    static let licenseStatus: String = "MIT (code) + OpenRAIL-M (model) — unverified for App Store distribution"
    static let isLicenseVerifiedForAppStore: Bool = false
}
