import Foundation

// MARK: - CreateGoogleSheetsTool (Phase B stub)

struct CreateGoogleSheetsTool: WorkflowTool {
    let name = "create_google_sheets"
    let description = "plan JSON을 Google Sheets로 내보낸다 (Phase B — 현재 OAuth 연결 필요)"
    let riskLevel: ToolRiskLevel = .moderate
    let scope: ToolScope = .officeLive
    let plannerVisible: Bool = false
    let availability: ToolAvailability = .future
    let inputSchema: [String: String] = [
        "plan_filename": "create_spreadsheet_plan이 생성한 plan JSON 파일명"
    ]

    func execute(input: ToolInput, context: ToolExecutionContext) async throws -> ToolResult {
        return ToolResult(
            status: .blocked,
            output: "",
            artifactPath: nil,
            error: "Google Sheets 내보내기는 아직 준비 중입니다. 현재는 로컬 XLSX 생성만 사용할 수 있습니다."
        )
    }
}
