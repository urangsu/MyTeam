import Foundation
import AppKit

// MARK: - OpenURLTool

struct OpenURLTool: WorkflowTool {
    let name = "open_url"
    let description = "기본 브라우저에서 URL을 연다 (http/https만 허용)"
    let riskLevel: ToolRiskLevel = .safe
    let scope: ToolScope = .browserDOM
    let inputSchema: [String: String] = [
        "url": "열 URL (http:// 또는 https:// 로 시작해야 함)"
    ]

    func execute(input: ToolInput, context: ToolExecutionContext) async throws -> ToolResult {
        guard let urlStr = input["url"], let url = URL(string: urlStr) else {
            throw ToolError.invalidInput("유효하지 않은 URL")
        }
        guard url.scheme == "http" || url.scheme == "https" else {
            throw ToolError.forbidden("http/https 외 scheme 금지: \(url.scheme ?? "없음")")
        }
        _ = await MainActor.run { NSWorkspace.shared.open(url) }
        return ToolResult(success: true, output: "\(urlStr) 열기 완료", artifactPath: nil, error: nil)
    }
}
