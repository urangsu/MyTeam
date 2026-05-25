import Foundation

// MARK: - ReadFileTool

struct ReadFileTool: WorkflowTool {
    let name = "read_file"
    let description = "Workspace 내 지원 파일(txt/md/csv/pdf/xlsx/docx/pptx)을 읽어 정규화된 내용을 반환한다"
    let riskLevel: ToolRiskLevel = .safe
    let scope: ToolScope = .workspaceRead
    let inputSchema: [String: String] = [
        "filename": "읽을 파일명 (Workspace 상대 경로, 예: report.md)"
    ]

    func execute(input: ToolInput, context: ToolExecutionContext) async throws -> ToolResult {
        guard let filename = input["filename"] else {
            throw ToolError.invalidInput("filename 필수")
        }
        let url = try safeWorkspaceURL(filename: filename, context: context)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ToolError.executionFailed("파일을 찾을 수 없음: \(filename)")
        }
        let intakeRequest = try FileIntakeService.makeRequest(fileURL: url, source: .filePicker)
        let intakeDecision = FileIntakePolicy.decision(for: intakeRequest)
        guard intakeDecision.status == .allowed else {
            return ToolResult(
                status: .blocked,
                output: "",
                artifactPath: nil,
                error: intakeDecision.message
            )
        }
        let result = FileIntakeService.readText(from: intakeRequest)
        guard result.status == .ready, let content = result.normalizedText ?? result.extractedText else {
            return ToolResult(
                status: .blocked,
                output: "",
                artifactPath: nil,
                error: result.userMessage
            )
        }

        return ToolResult(status: .succeeded, output: content, artifactPath: filename, error: nil)
    }
}
