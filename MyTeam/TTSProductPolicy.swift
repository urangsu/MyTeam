import Foundation

// MARK: - TTSProductPolicy
// Round 256TTS-OFFICIAL-ENGINE: Supertonic3 → MyTeam 공식 TTS 엔진 승격.
//
// 승격 근거:
//   - 로컬 ONNX 합성 성공, crash 없음
//   - 한국어 품질 조건부 수락 (수석님 기준)
//   - OpenRAIL-M / MIT 라이선스 확인 완료 (Round 252-253TTS)
//   - 고지/사용제한 notice gate 구현 완료 (Round 254TTS)
//
// 공식 엔진이지만 자동 재생 기본값은 OFF.
// bundle policy / release-wide integration gate는 아직 남아 있음.
// fallback TTS 없음. Apple TTS 없음. Qwen 없음.

enum TTSProductPolicy {

    // MARK: - Official Engine (Round 256TTS)

    static let officialEngine: TTSProviderKind  = .supertonic3   // MyTeam 공식 TTS 엔진
    static let officialEngineEnabled: Bool      = true            // 공식 엔진 등록됨
    static let autoSpeakDefaultEnabled: Bool    = false           // 자동 재생 기본 OFF
    static let characterVoiceEnabled: Bool      = true            // 캐릭터 말하기 허용
    static let agentVoiceEnabled: Bool          = true            // 에이전트 말하기 허용

    // MARK: - Product Surface

    static let userFacingTTSEnabled: Bool       = true   // 공식 엔진 등록 — 수동 발화 경로 존재
    static let labOnlyEnabled: Bool             = true   // TTS Lab / Supertonic3 + Animalese 검증 UI 유지
    static let supertonicOnlyCandidate: Bool    = true   // 유일한 TTS 엔진
    static let supertonicDefaultEnabled: Bool   = false  // 기본 비활성 (사용자가 TTS 켤 때만)
    static let supertonicAutoInitOnLaunch: Bool = false  // launch 자동 init 금지
    static let modelBundled: Bool               = false  // app bundle 미포함 (다음 gate)
    static let fallbackTTSAvailable: Bool       = false  // 폴백 없음

    // MARK: - License Gate (Round 252-253TTS 확인 완료)

    static let licenseVerified: Bool            = true   // OpenRAIL-M / MIT 확인
    static let commercialUseAllowed: Bool       = true   // license 조건 준수 전제
    static let modelRedistributionAllowed: Bool = true   // license notice 포함 전제
    static let appBundleAllowed: Bool           = true   // bundle policy 승인 전제

    // MARK: - Notice Gate (Round 254TTS)

    static let licenseNoticeRequired: Bool          = true  // 실험 전 라이선스 고지 확인 필수
    static let useRestrictionNoticeRequired: Bool   = true  // 사용 제한 고지 확인 필수
    static let userNoticeAcceptanceRequired: Bool   = true  // 고지 수락 없이 합성 불가

    // MARK: - Product Quality Gate

    static let koreanQualityAccepted: Bool      = true   // 조건부 수락 (수석님 확인, Round 256TTS)
    static let localRuntimeVerified: Bool       = true   // 로컬 합성 성공 + crash 없음 (Round 256TTS)
    static let bundlePolicyAccepted: Bool       = false  // 배포 방식 미확정 (다음 gate)
    static let releaseIntegrationApproved: Bool = false  // Release-wide UX gate 미통과

    // MARK: - Ship Gate

    /// release-wide / App Store 배포 gate.
    /// koreanQuality + localRuntime 통과. bundle + releaseIntegration 아직 미통과.
    static var canShipAsProductFeature: Bool {
        koreanQualityAccepted &&
        localRuntimeVerified &&
        bundlePolicyAccepted &&
        releaseIntegrationApproved &&
        licenseVerified
    }
}
