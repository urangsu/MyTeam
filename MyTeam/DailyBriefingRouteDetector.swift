import Foundation

enum DailyBriefingRouteDetector {
    static func isDailyBriefingRequest(_ message: String) -> Bool {
        let lower = message.lowercased()
        if lower.contains("앱스토어") || lower.contains("개인정보처리방침") || lower.contains("이용약관") {
            return false
        }
        if GoalContextEngine.isFileCreationRequest(message) {
            return false
        }
        if GoalContextEngine.referencesRecentFile(message) {
            return false
        }
        let markers = [
            "오늘 뭐 해야 해",
            "오늘 뭐 해야",
            "오늘 일정 뭐 있어",
            "오늘 일정",
            "오늘 브리핑",
            "오늘 브리핑 해줘",
            "오늘 브리핑해줘",
            "일정 브리핑",
            "메일 브리핑",
            "새 메일",
            "오늘 할 일 정리해",
            "오늘 할 일",
            "메일이랑 일정",
            "메일과 일정",
            "메일이랑 일정 보고 오늘 할 일 정리해",
            "이번 주 일정",
            "이번주 일정",
            "이번 주 일정 요약",
            "일정 요약해",
            "오늘 업무 정리",
            "오늘 브리핑 해",
            "오늘 브리핑해",
            "새 메일 몇 통",
            "중요한 메일",
            "메일 몇 통",
            "오늘 할 일 뭐야",
            "오늘 해야 할 일",
            "오늘 작업",
            "오늘 내 업무",
            "지금 뭐 해야",
            "지금 뭐 해야 해",
            "뭐 해야 되지",
            "뭐 해야 돼",
            "지금 이어서 할 일",
            "아까 하던 거",
            "다음 작업",
            "다음 액션",
            "이어서 할 일",
            "할 일 뭐야",
            "업무 브리핑"
        ]
        return markers.contains { lower.contains($0) }
    }
}
