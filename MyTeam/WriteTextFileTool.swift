import Foundation

// MARK: - WriteTextFileTool

struct WriteTextFileTool: WorkflowTool {
    let name = "write_text_file"
    let description = "텍스트 내용을 Workspace에 파일로 저장한다"
    let riskLevel: ToolRiskLevel = .moderate
    let scope: ToolScope = .artifactGeneration
    let inputSchema: [String: String] = [
        "filename": "저장할 파일명 (예: output.txt)",
        "content": "저장할 텍스트 내용"
    ]

    func execute(input: ToolInput, context: ToolExecutionContext) async throws -> ToolResult {
        guard let filename = input["filename"], let content = input["content"] else {
            throw ToolError.invalidInput("filename, content 필수")
        }
        let url = try safeWorkspaceURL(filename: filename, context: context)
        try content.write(to: url, atomically: true, encoding: .utf8)
        let summary = "\(filename) 저장 완료 (\(content.count)자)"
        return ToolResult(success: true, output: summary, artifactPath: filename, error: nil)
    }
}
