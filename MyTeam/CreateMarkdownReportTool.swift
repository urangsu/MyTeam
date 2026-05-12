import Foundation

// MARK: - CreateMarkdownReportTool

struct CreateMarkdownReportTool: WorkflowTool {
    let name = "create_markdown_report"
    let description = "제목과 본문으로 마크다운 보고서 파일을 생성한다"
    let riskLevel: ToolRiskLevel = .moderate
    let scope: ToolScope = .artifactGeneration
    let inputSchema: [String: String] = [
        "filename": "저장할 파일명 (예: report.md)",
        "title":    "보고서 제목",
        "content":  "마크다운 본문 내용"
    ]

    func execute(input: ToolInput, context: ToolExecutionContext) async throws -> ToolResult {
        guard let filename = input["filename"],
              let title    = input["title"],
              let content  = input["content"] else {
            throw ToolError.invalidInput("filename, title, content 필수")
        }
        let md = "# \(title)\n\n\(content)\n"
        let url = try safeWritableWorkspaceURL(filename: filename, context: context)
        try md.write(to: url, atomically: true, encoding: .utf8)
        let preview = String(content.prefix(200))
        return ToolResult(status: .succeeded, output: preview, artifactPath: filename, error: nil)
    }
}
