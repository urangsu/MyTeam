import Foundation

// MARK: - CreateGoogleSlidesTool (Phase B stub)

struct CreateGoogleSlidesTool: WorkflowTool {
    let name = "create_google_slides"
    let description = "plan JSON을 Google Slides로 내보낸다 (Phase B — 현재 OAuth 연결 필요)"
    let riskLevel: ToolRiskLevel = .moderate
    let inputSchema: [String: String] = [
        "plan_filename": "create_presentation_plan이 생성한 plan JSON 파일명"
    ]

    func execute(input: ToolInput, context: ToolExecutionContext) async throws -> ToolResult {
        throw ToolError.invalidInput(
            "Google 계정 연결이 필요합니다. 설정 > Google 연동에서 연결해주세요."
        )
    }
}
