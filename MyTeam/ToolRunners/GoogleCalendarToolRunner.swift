import Foundation

enum GoogleCalendarToolRunner {
    static func runToday(input: MyTeamToolInput) async -> ToolExecutionState {
        let hasToken = await MainActor.run {
            GoogleOAuthTokenStore.shared.hasToken(for: .googleCalendar)
        }
        guard hasToken else {
            return GoogleRunnerSupport.connectionFailureState(
                provider: .googleCalendar,
                purpose: "오늘 일정을 가져오려면"
            )
        }

        let now = Date()
        let items = await GoogleDailyBriefingCalendarProvider.shared.calendarItemsForToday(now: now)
        let calendarStatus = await MainActor.run {
            (
                message: GoogleDailyBriefingCalendarProvider.shared.statusMessage,
                fetchStatus: GoogleDailyBriefingCalendarProvider.shared.lastFetchStatus
            )
        }
        if items.isEmpty, calendarStatus.fetchStatus != .empty {
            return GoogleRunnerSupport.calendarFailureState(
                fetchStatus: calendarStatus.fetchStatus,
                message: calendarStatus.message
            )
        }

        return GoogleCalendarResultFormatter.resultState(
            items: items,
            statusMessage: calendarStatus.message
        )
    }
}
