import Foundation

struct GoogleOAuthConfig: Equatable {
    enum ClientType: String, Codable {
        case desktop
        case webServer

        var displayName: String {
            switch self {
            case .desktop: return "macOS Desktop"
            case .webServer: return "Web Server"
            }
        }
    }

    enum RedirectMode: String, Codable {
        case loopback
        case customURLScheme
        case notConfigured

        var displayName: String {
            switch self {
            case .loopback: return "Loopback"
            case .customURLScheme: return "Custom URL Scheme"
            case .notConfigured: return "Not Configured"
            }
        }
    }

    let clientID: String
    let clientType: ClientType
    let redirectMode: RedirectMode
    let bundleID: String?
    let appName: String

    static let placeholder = GoogleOAuthConfig(
        clientID: "",
        clientType: .desktop,
        redirectMode: .notConfigured,
        bundleID: Bundle.main.bundleIdentifier,
        appName: "MyTeam"
    )

    static func fromStoredConfig(_ stored: GoogleOAuthStoredConfig) -> GoogleOAuthConfig {
        GoogleOAuthConfig(
            clientID: stored.clientID,
            clientType: .desktop,
            redirectMode: stored.redirectMode,
            bundleID: Bundle.main.bundleIdentifier,
            appName: "MyTeam"
        )
    }
}
