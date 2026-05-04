import Foundation

// MARK: - GeneratePPTXTool

struct GeneratePPTXTool: WorkflowTool {
    let name = "generate_pptx"
    let description = "plan JSON 파일을 읽어 PPTX 프레젠테이션 파일을 생성한다"
    let riskLevel: ToolRiskLevel = .moderate
    let scope: ToolScope = .artifactGeneration
    let inputSchema: [String: String] = [
        "plan_filename": "create_presentation_plan이 생성한 plan JSON 파일명",
        "output_filename": "생성할 .pptx 파일명 (예: presentation.pptx)"
    ]

    func execute(input: ToolInput, context: ToolExecutionContext) async throws -> ToolResult {
        guard let planFilename = input["plan_filename"],
              let outputFilename = input["output_filename"] else {
            throw ToolError.invalidInput("plan_filename, output_filename 필수")
        }

        let planURL    = try safeWorkspaceURL(filename: planFilename,    context: context)
        let outputURL  = try safeWorkspaceURL(filename: outputFilename,  context: context)

        let result = try DocumentGenerationService.generatePPTX(planURL: planURL, outputURL: outputURL)

        await ArtifactStore.shared.registerArtifact(IndexedArtifact(
            id:         UUID().uuidString,
            workflowID: context.sessionID,
            title:      result.title,
            type:       .presentation,
            filename:   outputFilename,
            path:       outputURL.path,
            preview:    "\(result.pageCount)장 슬라이드",
            createdAt:  ISO8601DateFormatter().string(from: Date())
        ))

        return ToolResult(
            success:      true,
            output:       "\(outputFilename) 생성 완료 (\(result.pageCount)장)",
            artifactPath: outputFilename,
            error:        nil
        )
    }
}
