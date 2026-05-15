import Foundation

enum StarterActionPolicy: Sendable {
    static let allowedStarterActionIDs: Set<String> = [
        "회의록_양식",
        "앱_출시_체크리스트",
        "최근_문서_요약",
        "최근_문서_회의록",
        "최근_문서_액션아이템"
    ]

    static let blockedStarterActionIDs: Set<String> = [
        "메일_보내줘",
        "일정_만들어줘",
        "파일_삭제해줘",
        "외부_업로드",
        "캘린더_쓰기"
    ]

    static func isAllowed(_ actionID: String) -> Bool {
        return allowedStarterActionIDs.contains(actionID) && !blockedStarterActionIDs.contains(actionID)
    }

    static func isBlocked(_ actionID: String) -> Bool {
        return blockedStarterActionIDs.contains(actionID)
    }
}
