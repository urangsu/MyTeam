import Foundation

struct GoogleOAuthToken: Equatable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    let scopes: [GoogleOAuthScope]

    var isExpired: Bool {
        Date() >= expiresAt
    }
}
