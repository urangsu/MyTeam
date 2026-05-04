import Foundation

// MARK: - ReadFileTool

struct ReadFileTool: WorkflowTool {
    let name = "read_file"
    let description = "Workspace 내 텍스트 파일을 읽어 내용을 반환한다"
    let riskLevel: ToolRiskLevel = .safe
    let scope: ToolScope = .documentEditing
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
        let content = try String(contentsOf: url, encoding: .utf8)
        return ToolResult(success: true, output: content, artifactPath: filename, error: nil)
    }
}
