import Foundation

enum SupertonicTTSNoticePolicy {
    private static let noticeVersion = "2026-06-supertonic3-lab"
    private static let acceptedVersionKey = "supertonic3NoticeAcceptedVersion"

    static var isCurrentNoticeAccepted: Bool {
        UserDefaults.standard.string(forKey: acceptedVersionKey) == noticeVersion
    }

    static func acceptCurrentNotice() {
        UserDefaults.standard.set(noticeVersion, forKey: acceptedVersionKey)
    }

    static func resetNoticeAcceptance() {
        UserDefaults.standard.removeObject(forKey: acceptedVersionKey)
    }
}
