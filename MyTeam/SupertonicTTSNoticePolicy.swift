import Foundation

// MARK: - SupertonicTTSNoticePolicy
// Round 254TTS-NOTICE: Centralizes notice/acceptance policy for Supertonic TTS Lab.
// Acceptance is required before ONNX synthesis is available in TTSLabView.
// Release user-facing TTS remains locked regardless of notice acceptance.

enum SupertonicTTSNoticePolicy {

    static let currentNoticeVersion = "round254-2026-05"

    // MARK: - UserDefaults Keys

    static let licenseAcceptedKey       = "supertonic.licenseNoticeAccepted"
    static let useRestrictionsAcceptedKey = "supertonic.useRestrictionsAccepted"
    static let noticeVersionKey         = "supertonic.noticeVersionAccepted"

    // MARK: - State Queries

    static var licenseNoticeAccepted: Bool {
        UserDefaults.standard.bool(forKey: licenseAcceptedKey)
    }

    static var useRestrictionsAccepted: Bool {
        UserDefaults.standard.bool(forKey: useRestrictionsAcceptedKey)
    }

    static var acceptedNoticeVersion: String {
        UserDefaults.standard.string(forKey: noticeVersionKey) ?? ""
    }

    // All three conditions required: license + use restrictions + current version
    static var isCurrentNoticeAccepted: Bool {
        licenseNoticeAccepted &&
        useRestrictionsAccepted &&
        acceptedNoticeVersion == currentNoticeVersion
    }

    // MARK: - Actions

    static func acceptCurrentNotice() {
        UserDefaults.standard.set(true, forKey: licenseAcceptedKey)
        UserDefaults.standard.set(true, forKey: useRestrictionsAcceptedKey)
        UserDefaults.standard.set(currentNoticeVersion, forKey: noticeVersionKey)
    }

    static func resetNoticeAcceptance() {
        UserDefaults.standard.removeObject(forKey: licenseAcceptedKey)
        UserDefaults.standard.removeObject(forKey: useRestrictionsAcceptedKey)
        UserDefaults.standard.removeObject(forKey: noticeVersionKey)
    }

    // MARK: - Notice Text

    static let licenseNoticeText = """
    Supertonic3는 MyTeam의 유일한 TTS 후보입니다.

    모델은 OpenRAIL-M 및 MIT 라이선스 조건을 준수해야 하며, 제품 릴리즈 전까지 \
    품질 검증, 런타임 통합, 번들 정책, 릴리즈 UX gate를 통과해야 합니다.

    이 기능은 실험 기능이며 Release gate 전까지 제품 기능이 아닙니다.
    """

    static let useRestrictionsText = """
    다음 용도로 사용할 수 없습니다:
    · 실제 인물 사칭 또는 동의 없는 음성 위장
    · 기만적이거나 허위 정보를 전달하기 위한 음성 생성
    · 괴롭힘, 협박, 사기 또는 불법 목적
    · 개인 정보 악용 또는 해로운 공개

    사용 목적은 개발 실험 및 품질 검증에 한정됩니다.
    """
}
