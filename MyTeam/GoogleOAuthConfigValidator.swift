import Foundation

struct GoogleOAuthConfigValidationResult: Equatable {
    enum Status: String {
        case ready
        case missingClientID
        case unsupportedClientType
        case missingRedirectMode
        case noScopes
    }

    let status: Status
    let message: String

    var isReady: Bool { status == .ready }
}

enum GoogleOAuthConfigValidator {
    static func validate(_ config: GoogleOAuthStoredConfig) -> GoogleOAuthConfigValidationResult {
        if config.clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .init(status: .missingClientID, message: "앱 Google OAuth Client ID 설정이 필요합니다.")
        }

        if config.redirectMode != .customURLScheme {
            return .init(status: .missingRedirectMode, message: "Custom URL Scheme redirect mode를 선택해 주세요.")
        }

        if config.enabledScopes.isEmpty {
            return .init(status: .noScopes, message: "Calendar read-only scope가 필요합니다.")
        }

        return .init(status: .ready, message: "Google Calendar 읽기 로그인을 시작할 수 있습니다.")
    }
}
