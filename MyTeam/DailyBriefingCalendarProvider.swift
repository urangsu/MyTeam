import Foundation

protocol DailyBriefingCalendarProviding {
    func calendarItemsForToday(now: Date) async -> [DailyCalendarBriefingItem]
    var statusMessage: String { get }
}

struct EmptyDailyBriefingCalendarProvider: DailyBriefingCalendarProviding {
    let statusMessage: String = "Google Calendar 연결 후 오늘 일정이 표시됩니다."

    func calendarItemsForToday(now: Date) async -> [DailyCalendarBriefingItem] {
        []
    }
}

struct PreviewDailyBriefingCalendarProvider: DailyBriefingCalendarProviding {
    let statusMessage: String = "Calendar read-only 연동 준비 중입니다."

    func calendarItemsForToday(now: Date) async -> [DailyCalendarBriefingItem] {
        []
    }
}
