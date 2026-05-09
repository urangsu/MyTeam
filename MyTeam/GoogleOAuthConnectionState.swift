import Foundation

struct GoogleOAuthConnectionState: Equatable {
    enum Status: String, Codable {
        case notConfigured
        case notConnected
        case comingSoon
        case connected
        case needsReauth
        case error

        var badgeLabel: String {
            switch self {
            case .notConfigured: return "미설정"
            case .notConnected: return "미연결"
            case .comingSoon: return "준비 중"
            case .connected: return "연결됨"
            case .needsReauth: return "재인증 필요"
            case .error: return "오류"
            }
        }
    }

    let provider: AssistantConnector.Provider
    let status: Status
    let grantedScopes: [GoogleOAuthScope]
    let lastCheckedAt: Date?
    let message: String
}
