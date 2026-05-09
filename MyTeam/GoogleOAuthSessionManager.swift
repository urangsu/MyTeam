import AppKit
import AuthenticationServices
import Combine
import Foundation

@MainActor
final class GoogleOAuthSessionManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GoogleOAuthSessionManager()

    @Published private(set) var isConnecting: Bool = false
    @Published private(set) var lastErrorMessage: String?

    private var activeSession: ASWebAuthenticationSession?

    private override init() {}

    func startCalendarReadOnlyConnection(config: GoogleOAuthStoredConfig) async throws -> GoogleOAuthToken {
        isConnecting = true
        lastErrorMessage = nil
        defer {
            isConnecting = false
            activeSession = nil
        }

        do {
            let validation = GoogleOAuthConfigValidator.validate(config)
            guard validation.isReady else {
                lastErrorMessage = validation.message
                throw GoogleOAuthSessionError.invalidConfiguration(validation.message)
            }

            guard config.redirectMode == .customURLScheme else {
                lastErrorMessage = "Custom URL Scheme redirect만 지원합니다."
                throw GoogleOAuthSessionError.unsupportedRedirectMode
            }

            let pkce = try GoogleOAuthPKCEGenerator.generate()
            let state = UUID().uuidString
            let request = GoogleOAuthAuthorizationRequest(
                clientID: config.clientID,
                redirectURI: Self.redirectURI,
                scopes: [.calendarEventsReadonly],
                state: state,
                codeChallenge: pkce.codeChallenge,
                codeChallengeMethod: pkce.method
            )
            let authURL = try request.authorizationURL()

            let callbackURL = try await withCheckedThrowingContinuation { continuation in
                let session = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: Self.redirectScheme
                ) { callbackURL, error in
                    if let callbackURL {
                        continuation.resume(returning: callbackURL)
                        return
                    }
                    if let nsError = error as NSError?, nsError.domain == ASWebAuthenticationSessionError.errorDomain {
                        continuation.resume(throwing: GoogleOAuthSessionError.cancelled)
                        return
                    }
                    continuation.resume(throwing: GoogleOAuthSessionError.authenticationFailed)
                }
                session.prefersEphemeralWebBrowserSession = false
                session.presentationContextProvider = self
                activeSession = session
                guard session.start() else {
                    continuation.resume(throwing: GoogleOAuthSessionError.sessionFailedToStart)
                    return
                }
            }

            let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
            let items = components?.queryItems ?? []
            guard
                let code = items.first(where: { $0.name == "code" })?.value,
                let returnedState = items.first(where: { $0.name == "state" })?.value,
                returnedState == state
            else {
                if let returnedState = items.first(where: { $0.name == "state" })?.value, returnedState != state {
                    lastErrorMessage = "인증 상태 확인에 실패했습니다. 다시 시도해 주세요."
                    throw GoogleOAuthSessionError.stateMismatch
                } else {
                    lastErrorMessage = "인증 코드를 받지 못했습니다."
                    throw GoogleOAuthSessionError.invalidCallback
                }
            }

            let token = try await GoogleOAuthTokenExchangeService.exchangeCode(
                code: code,
                codeVerifier: pkce.codeVerifier,
                clientID: config.clientID,
                redirectURI: Self.redirectURI
            )

            try GoogleOAuthTokenStore.shared.saveToken(token, for: .googleCalendar)
            lastErrorMessage = nil
            return token
        } catch {
            if lastErrorMessage == nil {
                lastErrorMessage = Self.message(for: error)
            }
            throw error
        }
    }

    @MainActor
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let activeWindow = NSApp.windows.first(where: { $0.isKeyWindow }) ?? NSApp.windows.first
        return activeWindow ?? ASPresentationAnchor(contentRect: .zero, styleMask: [], backing: .buffered, defer: false)
    }

    private static let redirectScheme = "myteam"
    private static let redirectURI = "myteam:/oauth2redirect/google"

    private static func message(for error: Error) -> String {
        switch error {
        case GoogleOAuthSessionError.invalidConfiguration(let message):
            return message
        case GoogleOAuthSessionError.unsupportedRedirectMode:
            return "Custom URL Scheme redirect만 지원합니다."
        case GoogleOAuthSessionError.sessionFailedToStart:
            return "Google 로그인 세션을 시작하지 못했습니다."
        case GoogleOAuthSessionError.cancelled:
            return "Google 로그인 취소됨"
        case GoogleOAuthSessionError.invalidCallback:
            return "인증 코드를 받지 못했습니다."
        case GoogleOAuthSessionError.stateMismatch:
            return "인증 상태 확인에 실패했습니다. 다시 시도해 주세요."
        case GoogleOAuthSessionError.authenticationFailed:
            return "Google 로그인에 실패했습니다."
        case GoogleOAuthTokenExchangeError.missingAccessToken:
            return "토큰 응답을 확인할 수 없습니다."
        case GoogleOAuthTokenExchangeError.serverRejected(let reason):
            _ = reason
            return "Google 토큰 교환에 실패했습니다."
        case GoogleOAuthTokenStoreError.keychainError:
            return "Google 연결 정보를 안전하게 저장하지 못했습니다."
        case GoogleOAuthTokenStoreError.notFound:
            return "Google 연결 정보를 찾지 못했습니다."
        case GoogleOAuthTokenStoreError.encodingFailed, GoogleOAuthTokenStoreError.decodingFailed:
            return "Google 연결 정보를 처리하지 못했습니다."
        default:
            return "Google Calendar 연결 실패"
        }
    }
}

enum GoogleOAuthSessionError: Error {
    case invalidConfiguration(String)
    case unsupportedRedirectMode
    case sessionFailedToStart
    case cancelled
    case invalidCallback
    case stateMismatch
    case authenticationFailed
}
