import Foundation

struct GoogleOAuthAuthorizationRequest: Equatable {
    let clientID: String
    let redirectURI: String
    let scopes: [GoogleOAuthScope]
    let state: String
    let codeChallenge: String?
    let codeChallengeMethod: String?

    func authorizationURL() throws -> URL {
        guard !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GoogleOAuthAuthorizationRequestError.missingClientID
        }
        guard let baseComponents = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth") else {
            throw GoogleOAuthAuthorizationRequestError.invalidBaseURL
        }

        var items: [URLQueryItem] = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.map(\.rawValue).joined(separator: " ")),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "include_granted_scopes", value: "true")
        ]

        if let codeChallenge {
            items.append(URLQueryItem(name: "code_challenge", value: codeChallenge))
        }
        if let codeChallengeMethod {
            items.append(URLQueryItem(name: "code_challenge_method", value: codeChallengeMethod))
        }

        var components = baseComponents
        components.queryItems = items
        guard let url = components.url else {
            throw GoogleOAuthAuthorizationRequestError.invalidComponents
        }
        return url
    }
}

enum GoogleOAuthAuthorizationRequestError: Error {
    case missingClientID
    case invalidBaseURL
    case invalidComponents
}
