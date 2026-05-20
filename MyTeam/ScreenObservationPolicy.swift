import Foundation

// MARK: - ScreenObservationPolicy
// Round 243A-OBSERVE: 화면 관찰 정책 및 stub.
//
// 정책:
// - 상시 캡처 하드 블록 (허용 경로 없음)
// - 단발성 사용자 명시 요청만 허용 (future phase)
// - 스크린샷 원본 장기 저장 금지
// - OCR은 별도 future phase
// - 현재는 policy + stub만 구현

enum ScreenObservationPolicy {

    // MARK: - Implementation Level (Round 246A: P1-5)
    // 정책 선언 + stub만. 실제 캡처 구현 없음.
    static let implementationLevel: ImplementationLevel = .policyOnly

    // MARK: - Hard Blocks

    /// 상시 화면 캡처: 절대 금지
    static let continuousCaptureAllowed = false

    /// 자동 OCR 실행: 금지 (future phase)
    static let automaticOCRAllowed = false

    /// 스크린샷 원본 장기 저장: 금지
    static let rawScreenshotPersistenceAllowed = false

    // MARK: - Capability Status

    enum CapabilityStatus {
        case planned          // 구현 예정
        case requiresPermission   // 권한 필요
        case available        // 사용 가능
        case hardBlocked      // 정책상 금지
    }

    static var oneShotCapability: CapabilityStatus { .planned }
    static var continuousCaptureCapability: CapabilityStatus { .hardBlocked }
    static var ocrCapability: CapabilityStatus { .planned }

    // MARK: - Permission Stub (future)

    /// 단발성 화면 스냅샷 권한 요청 (future — 현재 미구현)
    static func requestOneShotScreenSnapshotPermission() async -> PermissionResult {
        // TODO (Mac local): CGRequestScreenCaptureAccess()
        return .notImplementedYet
    }

    enum PermissionResult {
        case granted
        case denied
        case notImplementedYet
    }

    // MARK: - User-Facing Messages

    static let plannedFeatureMessage = "화면 읽기는 다음 업데이트에서 제공됩니다."
    static let continuousCaptureBlockedMessage = "MyTeam은 화면을 항상 캡처하지 않습니다. 필요할 때만 직접 요청해 주세요."
}
