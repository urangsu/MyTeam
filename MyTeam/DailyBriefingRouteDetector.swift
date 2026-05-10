import Foundation

enum DailyBriefingRouteDetector {
    static func isDailyBriefingRequest(_ message: String) -> Bool {
        let lower = message.lowercased()
        let markers = [
            "오늘 뭐 해야 해",
            "오늘 뭐 해야",
            "오늘 일정 뭐 있어",
            "오늘 일정",
            "오늘 브리핑",
            "오늘 할 일 정리해",
            "오늘 할 일",
            "메일이랑 일정",
            "메일과 일정",
            "이번 주 일정",
            "이번주 일정",
            "일정 요약해",
            "오늘 업무 정리",
            "오늘 브리핑 해",
            "오늘 브리핑해"
        ]
        return markers.contains { lower.contains($0) }
    }
}
