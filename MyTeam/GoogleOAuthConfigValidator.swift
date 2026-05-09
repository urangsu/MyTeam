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
            return .init(status: .missingClientID, message: "Google OAuth Desktop client ID가 필요합니다.")
        }

        if config.redirectMode == .notConfigured {
            return .init(status: .missingRedirectMode, message: "Desktop OAuth redirect mode를 선택해 주세요.")
        }

        if config.enabledScopes.isEmpty {
            return .init(status: .noScopes, message: "Calendar read-only scope가 필요합니다.")
        }

        return .init(status: .ready, message: "Calendar read-only OAuth 연결 준비가 완료됐습니다.")
    }
}
