import Foundation

// MARK: - TTSProductPolicy
// Round 254TTS-NOTICE: Supertonic3 제품 출시 gate 정책.
//
// License gate: OpenRAIL-M / MIT 라이선스 확인 완료 (Round 252-253TTS).
// Product gate: 한국어 품질 / 로컬 런타임 / 번들 방식 / 릴리즈 UX 미통과 → 제품 기능 아직 불가.
// Notice gate: Round 254TTS — 개발자가 실험 기능 사용 전 고지 확인 필요.
// gate 실패 시 MyTeam v1 TTS 없이 출시.

enum TTSProductPolicy {

    // MARK: - Product Surface

    static let userFacingTTSEnabled: Bool       = false  // 제품 기본 TTS 없음
    static let supertonicOnlyCandidate: Bool    = true   // Supertonic 단독 후보
    static let supertonicDefaultEnabled: Bool   = false  // 기본 비활성
    static let supertonicAutoInitOnLaunch: Bool = false  // launch 자동 init 금지
    static let modelBundled: Bool               = false  // app bundle 미포함
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

    // MARK: - Product Quality Gate (미통과)

    static let koreanQualityAccepted: Bool      = false  // 수석님 음질 승인 전
    static let localRuntimeVerified: Bool       = false  // Mac 로컬 RTF/품질 실측 전
    static let bundlePolicyAccepted: Bool       = false  // 배포 방식 확정 전
    static let releaseIntegrationApproved: Bool = false  // Release UX/고지/정책 반영 전

    // MARK: - Ship Gate

    /// 5개 gate 모두 통과해야 제품 기능으로 출시 가능.
    /// 현재: koreanQualityAccepted / localRuntimeVerified / bundlePolicyAccepted / releaseIntegrationApproved 미통과.
    static var canShipAsProductFeature: Bool {
        koreanQualityAccepted &&
        localRuntimeVerified &&
        bundlePolicyAccepted &&
        releaseIntegrationApproved &&
        licenseVerified
    }
}
