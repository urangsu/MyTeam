import Foundation

enum GoogleCalendarClientError: Error {
    case notImplemented
    case missingToken
    case unsupportedScope
}

protocol GoogleCalendarClienting {
    func fetchEventsForToday() async throws -> [GoogleCalendarEvent]
    func fetchUpcomingEvents(limit: Int) async throws -> [GoogleCalendarEvent]
}

final class GoogleCalendarClient: GoogleCalendarClienting {
    static let shared = GoogleCalendarClient()

    private init() {}

    func fetchEventsForToday() async throws -> [GoogleCalendarEvent] {
        throw GoogleCalendarClientError.notImplemented
    }

    func fetchUpcomingEvents(limit: Int) async throws -> [GoogleCalendarEvent] {
        throw GoogleCalendarClientError.notImplemented
    }
}
