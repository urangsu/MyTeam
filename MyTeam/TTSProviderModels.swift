import Foundation

// MARK: - TTSProviderModels
// Round 251TTS: Supertonic3 단독 후보.
//
// 정책:
// - Apple TTS (AVSpeechSynthesizer): 절대 금지. 폴백 포함.
// - Supertonic3: 유일한 TTS 후보. TTSLab / 실험 scope 전용.
// - 라이선스/번들/릴리즈 gate 미검증 → 제품 기능 제공 안 함.
// - gate 실패 시 MyTeam v1 TTS 없이 출시.
// - provider 없음 → 무음 (silent). 폴백 없음.

// MARK: - TTSProviderKind

/// 앱에서 지원하는 TTS provider 종류.
/// Apple TTS: 영원히 금지. 폴백 포함.
enum TTSProviderKind: String, Codable, CaseIterable, Sendable {
    case supertonic3  // Supertonic3 ONNX, 유일한 후보, TTSLab 전용
}

// MARK: - TTSProductPolicy

/// Supertonic3 제품 출시 gate. 5개 모두 true여야 canShipAsProductFeature.
enum TTSProductPolicy {
    static let userFacingTTSEnabled: Bool       = false  // 제품 기본 TTS 없음
    static let supertonicOnlyCandidate: Bool    = true   // Supertonic 단독 후보
    static let supertonicDefaultEnabled: Bool   = false  // 기본 비활성
    static let supertonicAutoInitOnLaunch: Bool = false  // launch 자동 init 금지
    static let modelBundled: Bool               = false  // 모델 번들 금지
    static let licenseVerified: Bool            = false  // 라이선스 미검증
    static let fallbackTTSAvailable: Bool       = false  // 폴백 없음

    static var canShipAsProductFeature: Bool {
        // 상업 사용/모델 재배포/앱 번들/릴리즈 노출 — 모두 미검증. 출시 불가.
        false
    }
}

// MARK: - TTSProviderAvailability

enum TTSProviderAvailability: String, Codable, Sendable {
    case available           // 실제 동작 가능
    case experimental        // TTSLab / 실험용 enable 필요
    case missingModel        // 로컬 모델 파일 없음
    case licenseUnverified   // 라이선스/App Store 검증 전
    case runtimeUnavailable  // ONNX Runtime 미탑재
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
        reason: "로컬 모델 필요 (~398MB ONNX). 라이선스/번들 gate 미검증. TTSLab 전용.",
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
