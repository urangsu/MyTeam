import Foundation

// MARK: - ToolRegistry

final class ToolRegistry {
    static let shared = ToolRegistry()

    private var tools: [String: WorkflowTool] = [:]

    private init() {
        register(ReadFileTool())
        register(WriteTextFileTool())
        register(CreateMarkdownReportTool())
        register(CreatePresentationPlanTool())
        register(CreateSpreadsheetPlanTool())
        register(OpenURLTool())
    }

    func register(_ tool: WorkflowTool) {
        tools[tool.name] = tool
    }

    func lookup(name: String) -> WorkflowTool? {
        tools[name]
    }

    /// LLM 플래너 프롬프트에 포함할 도구 스키마 설명
    var toolSchemaDescription: String {
        tools.values
            .sorted { $0.name < $1.name }
            .map { tool in
                let params = tool.inputSchema
                    .sorted { $0.key < $1.key }
                    .map { "  - \($0.key): \($0.value)" }
                    .joined(separator: "\n")
                return "- \(tool.name) [\(tool.riskLevel.rawValue)]: \(tool.description)\n\(params)"
            }
            .joined(separator: "\n")
    }
}
