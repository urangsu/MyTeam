import Foundation

struct GoogleCalendarEventsResponse: Decodable {
    let items: [GoogleCalendarAPIEvent]
}

struct GoogleCalendarAPIEvent: Decodable {
    let id: String
    let summary: String?
    let location: String?
    let htmlLink: String?
    let start: GoogleCalendarAPIDateTime
    let end: GoogleCalendarAPIDateTime?
}

struct GoogleCalendarAPIDateTime: Decodable {
    let dateTime: String?
    let date: String?
    let timeZone: String?
}
