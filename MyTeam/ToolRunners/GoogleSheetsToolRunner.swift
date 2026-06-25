import Foundation

enum GoogleSheetsToolRunner {
    static func runRead(input: MyTeamToolInput) async -> ToolExecutionState {
        let hasSheetsToken = await MainActor.run {
            GoogleOAuthTokenStore.shared.hasToken(for: .googleSheets)
        }
        guard hasSheetsToken else {
            return GoogleRunnerSupport.connectionFailureState(
                provider: .googleSheets,
                purpose: "스프레드시트를 읽으려면"
            )
        }

        guard let request = GoogleRunnerSupport.googleSheetsReadRequest(from: input.query) else {
            return .failed(MyTeamToolFailure(
                title: "스프레드시트 URL 또는 ID가 필요합니다",
                message: "Google Sheets를 읽으려면 스프레드시트 URL 또는 ID와 범위가 필요합니다. 예: https://docs.google.com/spreadsheets/d/... 또는 {spreadsheetID} Sheet1!A1:D20",
                recoveryActions: [
                    MyTeamNextAction(id: "changeKeyword", title: "다시 입력", role: .normal)
                ]
            ))
        }

        do {
            let result = try await GoogleSheetsClient.shared.fetchValues(
                spreadsheetID: request.spreadsheetID,
                range: request.range
            )
            return GoogleSheetsResultFormatter.resultState(result)
        } catch {
            return GoogleRunnerSupport.googleSheetsFailureState(error)
        }
    }
}
