import Foundation

enum AssistantConnectorCatalog {
    static let connectors: [AssistantConnector] = [
        AssistantConnector(
            id: .googleCalendar,
            displayName: "Google Calendar",
            description: "오늘 일정과 다가오는 회의를 브리핑합니다.",
            capabilities: [.readCalendarEvents],
            isImplemented: true,
            notes: "Google 계정 연결 후 오늘 일정을 읽기 전용으로 가져옵니다."
        ),
        AssistantConnector(
            id: .googleSheets,
            displayName: "Google Sheets",
            description: "스프레드시트 생성과 내보내기를 준비합니다.",
            capabilities: [.createSpreadsheet],
            isImplemented: false,
            notes: "현재는 로컬 XLSX 생성만 사용할 수 있고, Google Sheets API 내보내기는 준비 중입니다."
        ),
        AssistantConnector(
            id: .gmail,
            displayName: "Gmail",
            description: "새 메일 수와 메일 요약 브리핑을 준비합니다.",
            capabilities: [.readEmailMetadata, .readEmailBody, .summarizeEmail, .createDraft, .sendEmail],
            isImplemented: false,
            notes: "연결 후 새 메일 수와 발신자, 제목을 확인할 수 있습니다."
        ),
        AssistantConnector(
            id: .naverMail,
            displayName: "Naver Mail",
            description: "네이버 메일 브리핑을 준비합니다.",
            capabilities: [.readEmailMetadata, .readEmailBody, .summarizeEmail],
            isImplemented: false,
            notes: "연동 준비 중입니다."
        ),
        AssistantConnector(
            id: .naverCalendar,
            displayName: "Naver Calendar",
            description: "네이버 캘린더 일정을 브리핑합니다.",
            capabilities: [.createCalendarEvent],
            isImplemented: false,
            notes: "연동 준비 중입니다."
        )
    ]

    static func connector(for provider: AssistantConnector.Provider) -> AssistantConnector? {
        connectors.first { $0.id == provider }
    }

    static func connectionState(for provider: AssistantConnector.Provider) -> GoogleOAuthConnectionState {
        switch provider {
        case .googleCalendar:
            let stored = GoogleOAuthConfigStore.shared.load()
            let validation = GoogleOAuthConfigValidator.validate(stored)
            let scopes = stored.enabledScopes.isEmpty ? [.calendarEventsReadonly] : stored.enabledScopes
            if !validation.isReady {
                return GoogleOAuthConnectionState(
                    provider: provider,
                    status: .notConfigured,
                    grantedScopes: scopes,
                    lastCheckedAt: nil,
                    message: "연결 준비 중"
                )
            }
            let token = try? GoogleOAuthTokenStore.shared.loadToken(for: provider)
            let connected = token != nil && (token?.isExpired == false || token?.refreshToken != nil)
            let status: GoogleOAuthConnectionState.Status
            if connected {
                status = .connected
            } else if token?.isExpired == true && token?.refreshToken == nil {
                status = .needsReauth
            } else {
                status = .notConnected
            }
            return GoogleOAuthConnectionState(
                provider: provider,
                status: status,
                grantedScopes: scopes,
                lastCheckedAt: Date(),
                message: status == .connected ? "연결됨" : (status == .needsReauth ? "재인증 필요" : "연결 준비 중")
            )
        case .googleSheets:
            let stored = GoogleOAuthConfigStore.shared.load()
            let validation = GoogleOAuthConfigValidator.validate(
                GoogleOAuthStoredConfig(
                    clientID: stored.clientID,
                    redirectMode: stored.redirectMode,
                    enabledScopes: [.spreadsheets],
                    updatedAt: stored.updatedAt
                )
            )
            if !validation.isReady {
                return GoogleOAuthConnectionState(
                    provider: provider,
                    status: .notConfigured,
                    grantedScopes: [.spreadsheets],
                    lastCheckedAt: nil,
                    message: "연결 준비 중"
                )
            }
            let token = try? GoogleOAuthTokenStore.shared.loadToken(for: provider)
            let connected = token != nil && (token?.isExpired == false || token?.refreshToken != nil)
            if connected {
                return GoogleOAuthConnectionState(
                    provider: provider,
                    status: .connected,
                    grantedScopes: token?.scopes ?? [.spreadsheets],
                    lastCheckedAt: Date(),
                    message: "OAuth 연결됨 · Sheets 내보내기는 준비 중"
                )
            }
            return GoogleOAuthConnectionState(
                provider: provider,
                status: token?.isExpired == true && token?.refreshToken == nil ? .needsReauth : .notConnected,
                grantedScopes: [.spreadsheets],
                lastCheckedAt: nil,
                message: "Google Sheets OAuth 연결 가능 · 내보내기는 준비 중"
            )
        case .gmail:
            return GoogleOAuthConnectionState(
                provider: provider,
                status: .comingSoon,
                grantedScopes: [.gmailMetadata],
                lastCheckedAt: nil,
                message: "준비 중"
            )
        case .naverMail:
            return GoogleOAuthConnectionState(
                provider: provider,
                status: .comingSoon,
                grantedScopes: [],
                lastCheckedAt: nil,
                message: "준비 중"
            )
        case .naverCalendar:
            return GoogleOAuthConnectionState(
                provider: provider,
                status: .comingSoon,
                grantedScopes: [],
                lastCheckedAt: nil,
                message: "준비 중"
            )
        }
    }
}
