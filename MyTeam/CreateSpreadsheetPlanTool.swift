import Foundation

// MARK: - CreateSpreadsheetPlanTool
// 스프레드시트 계획을 JSON 파일로 저장한다.
// data_json 형식: {"headers":["항목","값"],"rows":[["A","1"],["B","2"]]}

struct CreateSpreadsheetPlanTool: WorkflowTool {
    let name = "create_spreadsheet_plan"
    let description = "표 데이터를 JSON 파일로 저장한다 (스프레드시트 초안)"
    let riskLevel: ToolRiskLevel = .moderate
    let inputSchema: [String: String] = [
        "filename":  "저장할 파일명 (예: workbook_plan.json)",
        "title":     "스프레드시트 제목",
        "data_json": "표 데이터 JSON 문자열 (headers 배열, rows 2차원 배열)"
    ]

    func execute(input: ToolInput, context: ToolExecutionContext) async throws -> ToolResult {
        guard let filename = input["filename"],
              let title    = input["title"],
              let dataJSON = input["data_json"] else {
            throw ToolError.invalidInput("filename, title, data_json 필수")
        }

        // data_json 유효성 검증
        guard let dataData = dataJSON.data(using: .utf8),
              let _ = try? JSONSerialization.jsonObject(with: dataData) else {
            throw ToolError.invalidInput("data_json이 유효한 JSON이 아닙니다")
        }

        let wrapper: [String: Any] = ["title": title, "data": dataJSON]
        let outputJSON = try JSONSerialization.data(withJSONObject: wrapper, options: .prettyPrinted)
        let url = try safeWorkspaceURL(filename: filename, context: context)
        try outputJSON.write(to: url)

        let summary = "스프레드시트 초안 '\(title)' 생성 완료 → \(filename)"
        return ToolResult(success: true, output: summary, artifactPath: filename, error: nil)
    }
}
