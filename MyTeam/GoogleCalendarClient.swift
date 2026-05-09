import Foundation

enum GoogleCalendarClientError: Error {
    case notImplemented
    case missingToken
    case unsupportedScope
    case needsReauth
    case unauthorized
    case forbidden
    case network
    case decodeFailed
    case requestFailed
    case invalidResponse
}

protocol GoogleCalendarClienting {
    func fetchEventsForToday() async throws -> [GoogleCalendarEvent]
    func fetchUpcomingEvents(limit: Int) async throws -> [GoogleCalendarEvent]
}

final class GoogleCalendarClient: GoogleCalendarClienting {
    static let shared = GoogleCalendarClient()

    private let session: URLSession = .shared

    private init() {}

    func fetchEventsForToday() async throws -> [GoogleCalendarEvent] {
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        return try await fetchEvents(from: startOfDay, to: endOfDay, limit: 250)
    }

    func fetchUpcomingEvents(limit: Int) async throws -> [GoogleCalendarEvent] {
        let now = Date()
        let upperBound = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 30, to: now) ?? now.addingTimeInterval(30 * 24 * 3600)
        return try await fetchEvents(from: now, to: upperBound, limit: limit)
    }

    private func fetchEvents(from start: Date, to end: Date, limit: Int) async throws -> [GoogleCalendarEvent] {
        let token = try await authorizedToken()
        guard token.scopes.contains(.calendarEventsReadonly) else {
            throw GoogleCalendarClientError.unsupportedScope
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: formatter.string(from: start)),
            URLQueryItem(name: "timeMax", value: formatter.string(from: end)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "\(max(1, limit))")
        ]

        guard let url = components.url else { throw GoogleCalendarClientError.invalidResponse }

        let request = makeRequest(url: url, accessToken: token.accessToken)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GoogleCalendarClientError.invalidResponse
        }

        if http.statusCode == 401 {
            return try await retryAfterRefresh(from: start, to: end, limit: limit, originalToken: token)
        }
        if http.statusCode == 403 {
            throw GoogleCalendarClientError.forbidden
        }

        guard 200..<300 ~= http.statusCode else {
            throw GoogleCalendarClientError.requestFailed
        }

        let decoded: GoogleCalendarEventsResponse
        do {
            decoded = try JSONDecoder().decode(GoogleCalendarEventsResponse.self, from: data)
        } catch {
            throw GoogleCalendarClientError.decodeFailed
        }
        return decoded.items.compactMap { event in
            guard let startDate = Self.resolveDate(for: event.start) else { return nil }
            let endDate = event.end.flatMap { Self.resolveDate(for: $0) }
            return GoogleCalendarEvent(
                id: event.id,
                title: event.summary ?? "제목 없음",
                startDate: startDate,
                endDate: endDate,
                location: event.location,
                calendarName: nil,
                htmlLink: event.htmlLink.flatMap(URL.init(string:))
            )
        }
    }

    private func retryAfterRefresh(
        from start: Date,
        to end: Date,
        limit: Int,
        originalToken: GoogleOAuthToken
    ) async throws -> [GoogleCalendarEvent] {
        guard let refreshToken = originalToken.refreshToken else {
            throw GoogleCalendarClientError.needsReauth
        }

        let refreshed = try await GoogleOAuthTokenExchangeService.refreshAccessToken(
            refreshToken: refreshToken,
            clientID: GoogleOAuthConfigStore.shared.load().clientID
        )
        try? GoogleOAuthTokenStore.shared.saveToken(refreshed, for: .googleCalendar)
        return try await fetchEvents(from: start, to: end, limit: limit, with: refreshed)
    }

    private func fetchEvents(from start: Date, to end: Date, limit: Int, with token: GoogleOAuthToken) async throws -> [GoogleCalendarEvent] {
        guard token.scopes.contains(.calendarEventsReadonly) else {
            throw GoogleCalendarClientError.unsupportedScope
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: formatter.string(from: start)),
            URLQueryItem(name: "timeMax", value: formatter.string(from: end)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "\(max(1, limit))")
        ]

        guard let url = components.url else { throw GoogleCalendarClientError.invalidResponse }
        let request = makeRequest(url: url, accessToken: token.accessToken)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GoogleCalendarClientError.invalidResponse
        }
        if http.statusCode == 401 {
            throw GoogleCalendarClientError.unauthorized
        }
        if http.statusCode == 403 {
            throw GoogleCalendarClientError.forbidden
        }
        guard 200..<300 ~= http.statusCode else {
            throw GoogleCalendarClientError.requestFailed
        }

        let decoded: GoogleCalendarEventsResponse
        do {
            decoded = try JSONDecoder().decode(GoogleCalendarEventsResponse.self, from: data)
        } catch {
            throw GoogleCalendarClientError.decodeFailed
        }
        return decoded.items.compactMap { event in
            guard let startDate = Self.resolveDate(for: event.start) else { return nil }
            let endDate = event.end.flatMap { Self.resolveDate(for: $0) }
            return GoogleCalendarEvent(
                id: event.id,
                title: event.summary ?? "제목 없음",
                startDate: startDate,
                endDate: endDate,
                location: event.location,
                calendarName: nil,
                htmlLink: event.htmlLink.flatMap(URL.init(string:))
            )
        }
    }

    private func authorizedToken() async throws -> GoogleOAuthToken {
        guard let token = try GoogleOAuthTokenStore.shared.loadToken(for: .googleCalendar) else {
            throw GoogleCalendarClientError.missingToken
        }
        if !token.isExpired {
            return token
        }
        guard let refreshToken = token.refreshToken else {
            throw GoogleCalendarClientError.needsReauth
        }
        let refreshed = try await GoogleOAuthTokenExchangeService.refreshAccessToken(
            refreshToken: refreshToken,
            clientID: GoogleOAuthConfigStore.shared.load().clientID
        )
        try? GoogleOAuthTokenStore.shared.saveToken(refreshed, for: .googleCalendar)
        return refreshed
    }

    private func makeRequest(url: URL, accessToken: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private static func resolveDate(for value: GoogleCalendarAPIDateTime) -> Date? {
        if let dateTime = value.dateTime {
            if let parsed = isoDateFormatter.date(from: dateTime) {
                return parsed
            }
            return fallbackISODateFormatter.date(from: dateTime)
        }
        if let date = value.date {
            return dayDateFormatter.date(from: date)
        }
        return nil
    }

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let fallbackISODateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let dayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
