import Foundation

struct GoogleOAuthToken: Equatable, Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    let scopes: [GoogleOAuthScope]
    let tokenType: String
    let issuedAt: Date

    var isExpired: Bool {
        Date() >= expiresAt
    }

    init(
        accessToken: String,
        refreshToken: String?,
        expiresAt: Date,
        scopes: [GoogleOAuthScope],
        tokenType: String = "Bearer",
        issuedAt: Date = Date()
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.scopes = scopes
        self.tokenType = tokenType
        self.issuedAt = issuedAt
    }
}
