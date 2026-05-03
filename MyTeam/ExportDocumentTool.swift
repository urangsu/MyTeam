import Foundation

// MARK: - ExportDocumentTool
// target 파라미터로 로컬/Google 경로를 분기한다.

struct ExportDocumentTool: WorkflowTool {
    let name = "export_document"
    let description = "문서 플랜을 지정 대상으로 내보낸다 (localPPTX / localXLSX / googleSlides / googleSheets)"
    let riskLevel: ToolRiskLevel = .moderate
    let inputSchema: [String: String] = [
        "plan_filename":   "plan JSON 파일명",
        "output_filename": "출력 파일명 (로컬 내보내기 시 필수)",
        "target":          "localPPTX | localXLSX | googleSlides | googleSheets"
    ]

    func execute(input: ToolInput, context: ToolExecutionContext) async throws -> ToolResult {
        guard let target = input["target"] else {
            throw ToolError.invalidInput("target 필수 (localPPTX | localXLSX | googleSlides | googleSheets)")
        }

        switch target {
        case "localPPTX":
            return try await GeneratePPTXTool().execute(input: input, context: context)
        case "localXLSX":
            return try await GenerateXLSXTool().execute(input: input, context: context)
        case "googleSlides":
            return try await CreateGoogleSlidesTool().execute(input: input, context: context)
        case "googleSheets":
            return try await CreateGoogleSheetsTool().execute(input: input, context: context)
        default:
            throw ToolError.invalidInput("알 수 없는 target: \(target)")
        }
    }
}
