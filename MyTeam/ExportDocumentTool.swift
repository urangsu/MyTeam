import Foundation

// MARK: - ExportDocumentTool
// target 파라미터로 로컬/Google 경로를 분기한다.

struct ExportDocumentTool: WorkflowTool {
    let name = "export_document"
    let description = "문서 플랜을 지정 대상으로 내보낸다 (localPPTX / localXLSX / googleSlides / googleSheets)"
    let riskLevel: ToolRiskLevel = .moderate
    let scope: ToolScope = .artifactGeneration
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
            return await ToolExecutionLayer.execute(
                toolName: GeneratePPTXTool().name,
                input: input.parameters,
                declaredRisk: .moderate,
                context: context,
                sessionID: context.sessionID,
                stepTitle: "PPTX 생성",
                allowedScopes: [.artifactGeneration]
            )
        case "localXLSX":
            return await ToolExecutionLayer.execute(
                toolName: GenerateXLSXTool().name,
                input: input.parameters,
                declaredRisk: .moderate,
                context: context,
                sessionID: context.sessionID,
                stepTitle: "XLSX 생성",
                allowedScopes: [.artifactGeneration]
            )
        case "googleSlides":
            return await ToolExecutionLayer.execute(
                toolName: CreateGoogleSlidesTool().name,
                input: input.parameters,
                declaredRisk: .moderate,
                context: context,
                sessionID: context.sessionID,
                stepTitle: "Google Slides 내보내기",
                allowedScopes: [.officeLive]
            )
        case "googleSheets":
            return await ToolExecutionLayer.execute(
                toolName: CreateGoogleSheetsTool().name,
                input: input.parameters,
                declaredRisk: .moderate,
                context: context,
                sessionID: context.sessionID,
                stepTitle: "Google Sheets 내보내기",
                allowedScopes: [.officeLive]
            )
        default:
            throw ToolError.invalidInput("알 수 없는 target: \(target)")
        }
    }
}
