import Foundation

struct GoogleOAuthStoredConfig: Equatable, Codable {
    let clientID: String
    let redirectMode: GoogleOAuthConfig.RedirectMode
    let enabledScopes: [GoogleOAuthScope]
    let updatedAt: Date

    var isEmpty: Bool {
        clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

final class GoogleOAuthConfigStore {
    static let shared = GoogleOAuthConfigStore()

    private let userDefaultsKey = "MyTeam.GoogleOAuth.StoredConfig"

    private init() {}

    func load() -> GoogleOAuthStoredConfig {
        guard
            let data = UserDefaults.standard.data(forKey: userDefaultsKey),
            let config = try? JSONDecoder().decode(GoogleOAuthStoredConfig.self, from: data)
        else {
            return GoogleOAuthStoredConfig(
                clientID: "",
                redirectMode: .customURLScheme,
                enabledScopes: [.calendarEventsReadonly],
                updatedAt: Date()
            )
        }
        return config
    }

    func save(_ config: GoogleOAuthStoredConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
