import Foundation

enum GoogleOAuthTokenExchangeService {
    static func exchangeCode(
        code: String,
        codeVerifier: String,
        clientID: String,
        redirectURI: String
    ) async throws -> GoogleOAuthToken {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            "client_id": clientID,
            "code": code,
            "code_verifier": codeVerifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        let decoded = try JSONDecoder().decode(GoogleOAuthTokenResponse.self, from: data)

        guard let accessToken = decoded.accessToken else {
            throw GoogleOAuthTokenExchangeError.missingAccessToken
        }

        let scopes = decoded.scope?
            .split(separator: " ")
            .compactMap { GoogleOAuthScope(rawValue: String($0)) }
            ?? [.calendarEventsReadonly]
        let expiresAt = Date().addingTimeInterval(TimeInterval(decoded.expiresIn ?? 3600))

        return GoogleOAuthToken(
            accessToken: accessToken,
            refreshToken: decoded.refreshToken,
            expiresAt: expiresAt,
            scopes: scopes,
            tokenType: decoded.tokenType ?? "Bearer",
            issuedAt: Date()
        )
    }

    static func refreshAccessToken(
        refreshToken: String,
        clientID: String
    ) async throws -> GoogleOAuthToken {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        let decoded = try JSONDecoder().decode(GoogleOAuthTokenResponse.self, from: data)

        guard let accessToken = decoded.accessToken else {
            throw GoogleOAuthTokenExchangeError.missingAccessToken
        }

        let scopes = decoded.scope?
            .split(separator: " ")
            .compactMap { GoogleOAuthScope(rawValue: String($0)) }
            ?? [.calendarEventsReadonly]
        let expiresAt = Date().addingTimeInterval(TimeInterval(decoded.expiresIn ?? 3600))

        return GoogleOAuthToken(
            accessToken: accessToken,
            refreshToken: decoded.refreshToken ?? refreshToken,
            expiresAt: expiresAt,
            scopes: scopes,
            tokenType: decoded.tokenType ?? "Bearer",
            issuedAt: Date()
        )
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let errorResponse = try? JSONDecoder().decode(GoogleOAuthTokenErrorResponse.self, from: data)
            let message = errorResponse?.errorDescription ?? errorResponse?.error ?? "OAuth token endpoint rejected the request."
            throw GoogleOAuthTokenExchangeError.serverRejected(message)
        }
    }

    private static func formBody(_ parameters: [String: String]) -> Data {
        let body = parameters
            .sorted(by: { $0.key < $1.key })
            .map { key, value in
                "\(urlEncode(key))=\(urlEncode(value))"
            }
            .joined(separator: "&")
        return Data(body.utf8)
    }

    private static func urlEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=?")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

enum GoogleOAuthTokenExchangeError: Error {
    case missingAccessToken
    case serverRejected(String)
}

private struct GoogleOAuthTokenResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let scope: String?
    let tokenType: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case scope
        case tokenType = "token_type"
    }
}

private struct GoogleOAuthTokenErrorResponse: Decodable {
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}
