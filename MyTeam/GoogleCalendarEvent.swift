import Foundation

struct GoogleCalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date?
    let location: String?
    let calendarName: String?
    let htmlLink: URL?
}
