import Foundation

// MARK: - TTSProviderModels
// Round 253TTS: Supertonic3 adoption gate.
//
// 정책:
// - Supertonic3: 유일한 TTS 후보. TTSLab / 실험 scope 전용.
// - OpenRAIL-M 기반 상업 사용, 재배포, 번들링은 license 조건 준수 전제로 허용.
// - 한국어 품질, 로컬 런타임, 번들 정책, 릴리즈 UX gate 미통과 → 아직 제품 기능 제공 안 함.
// - gate 실패 시 MyTeam v1 TTS 없이 출시.
// - provider 없음 → 무음 (silent). 폴백 없음.

// MARK: - TTSProviderKind

/// 앱에서 지원하는 TTS provider 종류.
enum TTSProviderKind: String, Codable, CaseIterable, Sendable {
    case supertonic3  // Supertonic3 ONNX, 유일한 후보, TTSLab 전용
}

// MARK: - TTSProviderAvailability

enum TTSProviderAvailability: String, Codable, Sendable {
    case available           // 실제 동작 가능
    case experimental        // TTSLab / 실험용 enable 필요
    case missingModel        // 로컬 모델 파일 없음
    case releaseGateLocked   // License는 가능하나 품질/런타임/릴리즈 gate 전
    case runtimeUnavailable  // ONNX Runtime 미탑재
    case noticeRequired      // Runtime linked but notice not accepted
    case runtimeReady        // Runtime linked, model ready, notice accepted
}

// MARK: - TTSProviderStatus

struct TTSProviderStatus: Sendable {
    let kind: TTSProviderKind
    let availability: TTSProviderAvailability
    let displayName: String
    let reason: String
    let requiresLocalModel: Bool
    let isDefaultEnabled: Bool

    static let supertonic3 = TTSProviderStatus(
        kind: .supertonic3,
        availability: .experimental,
        displayName: "Supertonic3 (실험용)",
        reason: "로컬 모델 필요 (~398MB ONNX). License 조건 준수 전제. 품질/런타임/릴리즈 gate 전까지 TTSLab 전용.",
        requiresLocalModel: true,
        isDefaultEnabled: false
    )

    static var all: [TTSProviderStatus] { [.supertonic3] }
}

// MARK: - TTSOutput

/// TTS synthesis 결과 구조체.
struct TTSOutput: Sendable {
    let audioFileURL: URL?
    let duration: TimeInterval?
    let sampleRate: Int
    let providerKind: TTSProviderKind

    static func silent(provider: TTSProviderKind) -> TTSOutput {
        TTSOutput(audioFileURL: nil, duration: nil, sampleRate: 0, providerKind: provider)
    }
}

// MARK: - TTSProviderError

enum TTSProviderError: Error, Sendable {
    case noProviderSelected
    case missingRuntime
    case missingModel(files: [String])
    case inferenceError(String)
    case inferenceFailure(String)
    case audioConversionError
    case notEnabled
    case invalidVoicePreset(String)
}