import Foundation

// MARK: - Supertonic3TTSConfig
// Round 247TTS-SUPERTONIC3-POC: Supertonic3 provider 설정.
//
// 정책:
// - 기본 비활성화 (isEnabled = UserDefaults bool → false by default)
// - 로컬 모델 필요 (~/.cache/supertonic3/onnx/)
// - 자동 다운로드 절대 없음 — 사용자가 직접 다운로드해야 함
// - HuggingFace: Supertone/supertonic-3
// - Sample code license / model license are documented by upstream, but product release gates remain locked.
// - 44.1kHz WAV 출력 — 기존 24kHz AudioPlaybackService와 변환 필요 (248TTS에서 구현)

enum Supertonic3TTSConfig {

    // MARK: - Model Paths

    /// Supertonic3 ONNX 모델 디렉토리 (Python SDK 기본 경로 참조)
    /// 샌드박스 환경에서 homeDirectoryForCurrentUser는 컨테이너를 반환하므로
    /// ProcessInfo.processInfo.environment["HOME"]로 실제 홈 디렉토리를 사용한다.
    static var realHomeURL: URL {
        // getpwuid는 패스워드 DB를 직접 읽어 샌드박스 HOME 재매핑을 우회한다.
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            let path = String(cString: dir)
            if !path.isEmpty {
                return URL(fileURLWithPath: path, isDirectory: true)
            }
        }
        // fallback 1: 환경변수 (비샌드박스 환경)
        if let home = ProcessInfo.processInfo.environment["HOME"] {
            return URL(fileURLWithPath: home, isDirectory: true)
        }
        // fallback 2: 샌드박스 컨테이너 (최후 수단)
        return FileManager.default.homeDirectoryForCurrentUser
    }

    static var modelDirectoryURL: URL {
        realHomeURL.appendingPathComponent(".cache/supertonic3/onnx", isDirectory: true)
    }

    /// Voice style JSON 파일 디렉토리
    static var voiceStylesDirectoryURL: URL {
        realHomeURL.appendingPathComponent(".cache/supertonic3/voice_styles", isDirectory: true)
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

    /// 언어 선택 (auto / ko / en / ja). 기본 auto.
    static var selectedLanguage: String {
        UserDefaults.standard.string(forKey: "supertonic3Language") ?? "auto"
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

    /// Upstream states sample code is MIT and the model is OpenRAIL-M.
    /// Product release still requires compliance review, attribution/use-restriction handling,
    /// model redistribution review, and App Store distribution review.
    static let licenseStatus: String = "MIT sample code + OpenRAIL-M model — product compliance review pending"
    static let isLicenseVerifiedForAppStore: Bool = false
    static let isModelRedistributionApproved: Bool = false
    static let isCommercialProductGateApproved: Bool = false
}