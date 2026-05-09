import Foundation

protocol GoogleOAuthTokenStoring {
    func hasToken(for provider: AssistantConnector.Provider) -> Bool
    func loadToken(for provider: AssistantConnector.Provider) throws -> GoogleOAuthToken?
    func saveToken(_ token: GoogleOAuthToken, for provider: AssistantConnector.Provider) throws
    func deleteToken(for provider: AssistantConnector.Provider) throws
}

enum GoogleOAuthTokenStoreError: Error {
    case notImplemented
}

final class GoogleOAuthTokenStore: GoogleOAuthTokenStoring {
    static let shared = GoogleOAuthTokenStore()

    private init() {}

    func hasToken(for provider: AssistantConnector.Provider) -> Bool {
        false
    }

    func loadToken(for provider: AssistantConnector.Provider) throws -> GoogleOAuthToken? {
        throw GoogleOAuthTokenStoreError.notImplemented
    }

    func saveToken(_ token: GoogleOAuthToken, for provider: AssistantConnector.Provider) throws {
        throw GoogleOAuthTokenStoreError.notImplemented
    }

    func deleteToken(for provider: AssistantConnector.Provider) throws {
        throw GoogleOAuthTokenStoreError.notImplemented
    }
}
