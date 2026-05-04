import Foundation

// MARK: - CreateSpreadsheetPlanTool
// 스프레드시트 계획을 JSON 파일로 저장한다.
// data_json 형식: {"headers":["항목","값"],"rows":[["A","1"],["B","2"]]}
// 출력: {"format":"xlsx-plan-v1","title":"...","data":{...}} — XLSXWriter가 바로 읽는 구조

struct CreateSpreadsheetPlanTool: WorkflowTool {
    let name = "create_spreadsheet_plan"
    let description = "표 데이터를 JSON 파일로 저장한다 (XLSXWriter 호환 구조)"
    let riskLevel: ToolRiskLevel = .moderate
    let scope: ToolScope = .artifactGeneration
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

        // data_json 파싱 — JSON string이 아니라 실제 객체로 저장
        guard let dataBytes = dataJSON.data(using: .utf8),
              let dataObj = try? JSONSerialization.jsonObject(with: dataBytes) as? [String: Any] else {
            throw ToolError.invalidInput("data_json이 유효한 JSON 객체가 아닙니다 (예: {\"headers\":[...],\"rows\":[[...]]})")
        }

        let headers = dataObj["headers"] as? [String] ?? []
        let rows = dataObj["rows"] as? [[Any]] ?? []

        let wrapper: [String: Any] = [
            "format": "xlsx-plan-v1",
            "title": title,
            "columnCount": headers.count,
            "rowCount": rows.count,
            "data": dataObj
        ]
        let outputJSON = try JSONSerialization.data(withJSONObject: wrapper, options: [.prettyPrinted, .sortedKeys])
        let url = try safeWorkspaceURL(filename: filename, context: context)
        try outputJSON.write(to: url)

        let preview = "스프레드시트 '\(title)' — \(headers.count)열 × \(rows.count)행 생성 완료"
        return ToolResult(success: true, output: preview, artifactPath: filename, error: nil)
    }
}
