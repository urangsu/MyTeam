import Foundation

struct GoogleSheetsReadRequest: Sendable, Equatable {
    let spreadsheetID: String
    let range: String
}

enum GoogleRunnerSupport {
    static func connectionFailureState(
        provider: AssistantConnector.Provider,
        purpose: String
    ) -> ToolExecutionState {
        .failed(MyTeamToolFailure(
            title: "\(provider.displayName) 연결이 필요합니다",
            message: "\(purpose)하려면 비서 연결에서 \(provider.displayName) 읽기 연결을 먼저 완료하세요.",
            recoveryActions: [
                MyTeamNextAction(id: "openAssistantConnection", title: "비서 연결", role: .normal)
            ]
        ))
    }

    static func readFailureState(
        provider: AssistantConnector.Provider,
        message: String?
    ) -> ToolExecutionState {
        .failed(MyTeamToolFailure(
            title: "\(provider.displayName) 읽기 연결을 확인해야 합니다",
            message: message ?? "연결은 되어 있지만 값을 읽지 못했습니다. 권한 또는 재인증 상태를 확인하세요.",
            recoveryActions: [
                MyTeamNextAction(id: "openAssistantConnection", title: "비서 연결", role: .normal),
                MyTeamNextAction(id: "searchAgain", title: "다시 시도", role: .normal)
            ]
        ))
    }

    static func googleSheetsReadRequest(from query: String?) -> GoogleSheetsReadRequest? {
        let raw = (query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        if let url = URL(string: raw), let host = url.host, host.contains("docs.google.com") {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            guard let range = explicitRange(from: url, components: components) else { return nil }
            let parts = url.pathComponents
            if let index = parts.firstIndex(of: "d"), parts.indices.contains(index + 1) {
                return GoogleSheetsReadRequest(
                    spreadsheetID: parts[index + 1],
                    range: range
                )
            }
        }

        let tokens = raw
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .map(String.init)
        guard let idToken = tokens.first else { return nil }
        let id = spreadsheetID(from: idToken) ?? idToken
        let rawRange = tokens.dropFirst().first.map { String($0) }
        guard isLikelySpreadsheetID(id) else { return nil }
        guard let range = rawRange.flatMap(sanitizedSheetRange) else { return nil }
        return GoogleSheetsReadRequest(
            spreadsheetID: id,
            range: range
        )
    }

    static func googleSheetsFailureState(_ error: Error) -> ToolExecutionState {
        let title: String
        let message: String
        let actions: [MyTeamNextAction]

        switch error {
        case GoogleSheetsClientError.missingToken:
            title = "Google Sheets 연결이 필요합니다"
            message = "Google Sheets 읽기 연결을 먼저 완료하세요."
            actions = [MyTeamNextAction(id: "openAssistantConnection", title: "비서 연결", role: .normal)]
        case GoogleSheetsClientError.needsReauth, GoogleSheetsClientError.unauthorized:
            title = "Google Sheets 재인증이 필요합니다"
            message = "Google 로그인 토큰이 만료되었거나 사용할 수 없습니다."
            actions = [MyTeamNextAction(id: "openAssistantConnection", title: "비서 연결", role: .normal)]
        case GoogleSheetsClientError.unsupportedScope:
            title = "Google Sheets 읽기 권한이 필요합니다"
            message = "현재 토큰에 spreadsheets.readonly 권한이 없습니다. Google Sheets 읽기 연결을 다시 진행해 주세요."
            actions = [MyTeamNextAction(id: "openAssistantConnection", title: "비서 연결", role: .normal)]
        case GoogleSheetsClientError.forbidden:
            title = "시트 접근 권한이 없습니다"
            message = "해당 스프레드시트를 볼 수 있는 Google 계정으로 연결했는지 확인하세요."
            actions = [MyTeamNextAction(id: "openAssistantConnection", title: "비서 연결", role: .normal)]
        case GoogleSheetsClientError.notFound:
            title = "스프레드시트를 찾지 못했습니다"
            message = "spreadsheetId 또는 URL이 올바른지 확인하세요. 예: spreadsheetId Sheet1!A1:D20"
            actions = [MyTeamNextAction(id: "changeKeyword", title: "다시 입력", role: .normal)]
        case GoogleSheetsClientError.invalidRequest:
            title = "시트 범위를 확인하세요"
            message = "예: spreadsheetId Sheet1!A1:D20 형식으로 입력해 주세요."
            actions = [MyTeamNextAction(id: "changeKeyword", title: "범위 바꾸기", role: .normal)]
        case GoogleSheetsClientError.decodeFailed:
            title = "시트 응답을 해석하지 못했습니다"
            message = "Google Sheets 응답 형식이 예상과 다릅니다."
            actions = [MyTeamNextAction(id: "searchAgain", title: "다시 시도", role: .normal)]
        default:
            title = "Google Sheets 값을 가져오지 못했습니다"
            message = "네트워크 상태 또는 Google Sheets API 설정을 확인하세요."
            actions = [MyTeamNextAction(id: "searchAgain", title: "다시 시도", role: .normal)]
        }

        return .failed(MyTeamToolFailure(
            title: title,
            message: message,
            recoveryActions: actions
        ))
    }

    static func calendarFailureState(fetchStatus: GoogleCalendarFetchStatus, message: String) -> ToolExecutionState {
        let actions: [MyTeamNextAction]
        switch fetchStatus {
        case .missingToken, .needsReauth, .forbidden:
            actions = [
                MyTeamNextAction(id: "openAssistantConnection", title: "비서 연결", role: .normal)
            ]
        default:
            actions = [
                MyTeamNextAction(id: "searchAgain", title: "다시 시도", role: .normal)
            ]
        }
        let title: String
        switch fetchStatus {
        case .missingToken:
            title = "Google Calendar 연결이 필요합니다"
        case .needsReauth:
            title = "Google Calendar 재인증이 필요합니다"
        case .forbidden:
            title = "Google Calendar 읽기 권한이 필요합니다"
        default:
            title = "Google Calendar 일정을 가져오지 못했습니다"
        }
        return .failed(MyTeamToolFailure(
            title: title,
            message: message,
            recoveryActions: actions
        ))
    }

    private nonisolated static func spreadsheetID(from value: String) -> String? {
        guard let url = URL(string: value), let host = url.host, host.contains("docs.google.com") else {
            return nil
        }
        let parts = url.pathComponents
        guard let index = parts.firstIndex(of: "d"), parts.indices.contains(index + 1) else {
            return nil
        }
        return parts[index + 1]
    }

    private nonisolated static func isLikelySpreadsheetID(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 20 else { return false }
        return trimmed.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
    }

    private nonisolated static func explicitRange(from url: URL, components: URLComponents?) -> String? {
        if let queryRange = components?.queryItems?.first(where: { $0.name == "range" })?.value,
           let range = sanitizedSheetRange(queryRange) {
            return range
        }
        if let fragment = url.fragment {
            for pair in fragment.split(separator: "&").map(String.init) {
                guard pair.hasPrefix("range=") else { continue }
                let encoded = String(pair.dropFirst("range=".count))
                let decoded = encoded.removingPercentEncoding ?? encoded
                return sanitizedSheetRange(decoded)
            }
        }
        return nil
    }

    private nonisolated static func sanitizedSheetRange(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        return trimmed
    }
}
