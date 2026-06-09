import Foundation

enum GoogleOAuthPolicyDecision: Equatable {
    case autoAllowed
    case requiresApproval(reason: String)
    case blocked(reason: String)
}

enum GoogleOAuthPolicy {
    static func decision(for scope: GoogleOAuthScope) -> GoogleOAuthPolicyDecision {
        switch scope {
        case .calendarEventsReadonly:
            return .autoAllowed
        case .spreadsheets:
            return .requiresApproval(reason: "Google Sheets 생성/수정은 외부 파일 쓰기라 사용자 승인 후 실행합니다.")
        case .gmailMetadata:
            return .autoAllowed
        case .gmailReadonly:
            return .requiresApproval(reason: "메일 본문에는 민감정보가 포함될 수 있어 명시 확인 후 사용합니다.")
        }
    }
}
