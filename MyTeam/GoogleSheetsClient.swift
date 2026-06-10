import Foundation

enum GoogleSheetsClientError: Error {
    case missingToken
    case unsupportedScope
    case needsReauth
    case unauthorized
    case forbidden
    case notFound
    case invalidRequest
    case decodeFailed
    case requestFailed
    case invalidResponse
}

struct GoogleSheetsReadResult: Sendable, Equatable {
    let spreadsheetID: String
    let range: String
    let values: [[String]]

    nonisolated var rowCount: Int { values.count }
    nonisolated var columnCount: Int { values.map(\.count).max() ?? 0 }
    nonisolated var headers: [String] { values.first ?? [] }
    nonisolated var dataRows: [[String]] { values.isEmpty ? [] : Array(values.dropFirst()) }
}

final class GoogleSheetsClient {
    static let shared = GoogleSheetsClient()

    private let session: URLSession = .shared

    private init() {}

    func fetchValues(spreadsheetID: String, range: String) async throws -> GoogleSheetsReadResult {
        let token = try await authorizedToken()
        return try await fetchValues(spreadsheetID: spreadsheetID, range: range, token: token, allowRetry: true)
    }

    private func fetchValues(
        spreadsheetID: String,
        range: String,
        token: GoogleOAuthToken,
        allowRetry: Bool
    ) async throws -> GoogleSheetsReadResult {
        guard token.scopes.contains(.spreadsheetsReadonly) || token.scopes.contains(.spreadsheets) else {
            throw GoogleSheetsClientError.unsupportedScope
        }

        guard let encodedRange = range.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw GoogleSheetsClientError.invalidRequest
        }
        guard var components = URLComponents(string: "https://sheets.googleapis.com/v4/spreadsheets/\(spreadsheetID)/values/\(encodedRange)") else {
            throw GoogleSheetsClientError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "majorDimension", value: "ROWS"),
            URLQueryItem(name: "valueRenderOption", value: "FORMATTED_VALUE"),
            URLQueryItem(name: "dateTimeRenderOption", value: "FORMATTED_STRING")
        ]
        guard let url = components.url else { throw GoogleSheetsClientError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GoogleSheetsClientError.invalidResponse
        }
        if http.statusCode == 401 {
            guard allowRetry else { throw GoogleSheetsClientError.unauthorized }
            return try await retryAfterRefresh(spreadsheetID: spreadsheetID, range: range, originalToken: token)
        }
        if http.statusCode == 403 {
            throw GoogleSheetsClientError.forbidden
        }
        if http.statusCode == 404 {
            throw GoogleSheetsClientError.notFound
        }
        if http.statusCode == 400 {
            throw GoogleSheetsClientError.invalidRequest
        }
        guard 200..<300 ~= http.statusCode else {
            throw GoogleSheetsClientError.requestFailed
        }

        let decoded: GoogleSheetsValuesResponse
        do {
            decoded = try JSONDecoder().decode(GoogleSheetsValuesResponse.self, from: data)
        } catch {
            throw GoogleSheetsClientError.decodeFailed
        }
        return GoogleSheetsReadResult(
            spreadsheetID: spreadsheetID,
            range: decoded.range ?? range,
            values: decoded.values?.map { row in row.map(\.stringValue) } ?? []
        )
    }

    private func authorizedToken() async throws -> GoogleOAuthToken {
        guard let token = try GoogleOAuthTokenStore.shared.loadToken(for: .googleSheets) else {
            throw GoogleSheetsClientError.missingToken
        }
        if !token.isExpired {
            return token
        }
        guard let refreshToken = token.refreshToken else {
            throw GoogleSheetsClientError.needsReauth
        }
        let refreshed = try await GoogleOAuthTokenExchangeService.refreshAccessToken(
            refreshToken: refreshToken,
            clientID: GoogleOAuthConfigStore.shared.load().clientID,
            fallbackScopes: token.scopes.isEmpty ? [.spreadsheetsReadonly] : token.scopes
        )
        try? GoogleOAuthTokenStore.shared.saveToken(refreshed, for: .googleSheets)
        return refreshed
    }

    private func retryAfterRefresh(
        spreadsheetID: String,
        range: String,
        originalToken: GoogleOAuthToken
    ) async throws -> GoogleSheetsReadResult {
        guard let refreshToken = originalToken.refreshToken else {
            throw GoogleSheetsClientError.needsReauth
        }
        let refreshed = try await GoogleOAuthTokenExchangeService.refreshAccessToken(
            refreshToken: refreshToken,
            clientID: GoogleOAuthConfigStore.shared.load().clientID,
            fallbackScopes: originalToken.scopes.isEmpty ? [.spreadsheetsReadonly] : originalToken.scopes
        )
        try? GoogleOAuthTokenStore.shared.saveToken(refreshed, for: .googleSheets)
        return try await fetchValues(spreadsheetID: spreadsheetID, range: range, token: refreshed, allowRetry: false)
    }
}

private struct GoogleSheetsValuesResponse: Decodable {
    let range: String?
    let majorDimension: String?
    let values: [[GoogleSheetCellValue]]?
}

private enum GoogleSheetCellValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .null:
            return ""
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else {
            self = .string("")
        }
    }
}
