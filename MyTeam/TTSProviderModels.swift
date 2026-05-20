import Foundation

// MARK: - TTSProviderModels
// Round 247TTS-SUPERTONIC3-POC: TTS provider 정책 타입 정의.
//
// 정책:
// - Apple TTS (AVSpeechSynthesizer)는 이 파일 어디에도 없음.
//   프로젝트 정책상 영원히 금지. 폴백 포함 절대 사용 안 함.
// - Qwen3: 기본 비활성화. Developer Lab override만 허용.
// - Supertonic3: 실험용, 로컬 모델 필요, 기본 off.
// - provider 없음 → 무음 (silent). Apple TTS 폴백 없음.

// MARK: - TTSProviderKind

/// 앱에서 지원하는 TTS provider 종류.
/// Apple TTS는 프로젝트 정책상 절대 추가하지 않는다.
enum TTSProviderKind: String, Codable, CaseIterable, Sendable {
    case qwen3MLX     // 기존 Qwen3-TTS MLX 4bit, 기본 비활성화
    case supertonic3  // Supertonic3 ONNX, 실험용, 로컬 모델 필요
}

// MARK: - TTSProviderAvailability

enum TTSProviderAvailability: String, Codable, Sendable {
    case available           // 실제 동작 가능
    case experimental        // skeleton / 실험용 enable 필요
    case disabledByPolicy    // 정책상 비활성 (Qwen3 기본 상태)
    case missingModel        // 로컬 모델 파일 없음
    case licenseUnverified   // 라이선스/App Store 검증 전
    case runtimeUnavailable  // Cloud 환경 / ONNX Runtime 미탑재
}

// MARK: - TTSProviderStatus

struct TTSProviderStatus: Sendable {
    let kind: TTSProviderKind
    let availability: TTSProviderAvailability
    let displayName: String
    let reason: String
    let requiresLocalModel: Bool
    let isDefaultEnabled: Bool  // 둘 다 false

    static let qwen3MLX = TTSProviderStatus(
        kind: .qwen3MLX,
        availability: .disabledByPolicy,
        displayName: "Qwen3-TTS (MLX 4bit)",
        reason: "기본 비활성화. Developer Lab에서만 수동 재활성화 가능.",
        requiresLocalModel: true,
        isDefaultEnabled: false
    )

    static let supertonic3 = TTSProviderStatus(
        kind: .supertonic3,
        availability: .experimental,
        displayName: "Supertonic3 (실험용)",
        reason: "로컬 모델 필요 (~398MB ONNX). 실험용 enable 후 사용 가능.",
        requiresLocalModel: true,
        isDefaultEnabled: false
    )

    static var all: [TTSProviderStatus] { [.qwen3MLX, .supertonic3] }
}

// MARK: - TTSOutput

/// TTS synthesis 결과 구조체.
/// Cloud 환경에서는 audioFileURL = nil, pcmBuffer = nil.
struct TTSOutput: Sendable {
    let audioFileURL: URL?         // 생성된 WAV 파일 경로 (nil = inference 미실행)
    let duration: TimeInterval?    // 오디오 길이 (초)
    let sampleRate: Int            // 샘플레이트 (Supertonic3 = 44100, Qwen3 = 24000)
    let providerKind: TTSProviderKind

    static func silent(provider: TTSProviderKind) -> TTSOutput {
        TTSOutput(audioFileURL: nil, duration: nil, sampleRate: 0, providerKind: provider)
    }
}

// MARK: - TTSProviderError

enum TTSProviderError: Error, Sendable {
    case noProviderSelected          // TTSRoutingPolicy.selectedProvider() == nil
    case missingRuntime              // ONNX Runtime 없음 (Cloud 환경)
    case missingModel(files: [String])
    case inferenceError(String)
    case audioConversionError
    case disabledByPolicy            // Qwen3 등 정책상 차단된 provider 호출
}
