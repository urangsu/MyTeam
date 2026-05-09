import Foundation

protocol DailyBriefingCalendarProviding {
    func calendarItemsForToday(now: Date) async -> [DailyCalendarBriefingItem]
    var statusMessage: String { get }
}

struct EmptyDailyBriefingCalendarProvider: DailyBriefingCalendarProviding {
    let statusMessage: String = "Google Calendar 연결 후 오늘 일정이 표시됩니다."

    func calendarItemsForToday(now: Date) async -> [DailyCalendarBriefingItem] {
        _ = now
        return [] as [DailyCalendarBriefingItem]
    }
}

final class GoogleDailyBriefingCalendarProvider: DailyBriefingCalendarProviding {
    static let shared = GoogleDailyBriefingCalendarProvider()

    private(set) var statusMessage: String = "Google Calendar 연결 후 오늘 일정이 표시됩니다."
    private(set) var lastFetchStatus: String = "not_fetched"

    private init() {}

    func calendarItemsForToday(now: Date) async -> [DailyCalendarBriefingItem] {
        _ = now
        lastFetchStatus = "loading"

        guard GoogleOAuthTokenStore.shared.hasToken(for: .googleCalendar) else {
            statusMessage = "Google Calendar 연결 후 오늘 일정이 표시됩니다."
            lastFetchStatus = "missing_token"
            return []
        }

        do {
            let events = try await GoogleCalendarClient.shared.fetchEventsForToday()
            if events.isEmpty {
                statusMessage = "오늘 일정이 없습니다."
                lastFetchStatus = "empty"
            } else {
                statusMessage = "오늘 일정 \(events.count)개를 불러왔습니다."
                lastFetchStatus = "ready"
            }

            return events.map { event in
                DailyCalendarBriefingItem(
                    id: UUID(uuidString: event.id) ?? UUID(),
                    title: event.title,
                    timeText: Self.timeText(for: event.startDate, endDate: event.endDate),
                    location: event.location,
                    source: .googleCalendar
                )
            }
        } catch {
            switch error {
            case GoogleCalendarClientError.missingToken:
                statusMessage = "Google Calendar 연결 후 오늘 일정이 표시됩니다."
                lastFetchStatus = "missing_token"
            case GoogleCalendarClientError.needsReauth:
                statusMessage = "Google Calendar 재인증이 필요합니다."
                lastFetchStatus = "needs_reauth"
            default:
                statusMessage = "Google Calendar 연결 실패"
                lastFetchStatus = "error"
            }
            return []
        }
    }

    private static func timeText(for startDate: Date, endDate: Date?) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        if let endDate {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
        return formatter.string(from: startDate)
    }
}
