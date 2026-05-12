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
        register(WorkspaceRevealFileTool())
        register(WorkspaceCopyPathTool())
        register(GeneratePPTXTool())
        register(GenerateXLSXTool())
        register(CreateGoogleSlidesTool())
        register(CreateGoogleSheetsTool())
        register(ExportDocumentTool())
    }

    func register(_ tool: WorkflowTool) {
        if tool.scope == .chatBasic {
            AppLog.error("[ToolRegistry] scope 미선언/기본값 사용 금지: '\(tool.name)'")
            return
        }
        tools[tool.name] = tool
    }

    func lookup(name: String) -> WorkflowTool? {
        tools[name]
    }

    /// 특정 scope에 해당하는 도구 목록
    func tools(for scopes: Set<ToolScope>) -> [WorkflowTool] {
        tools.values.filter { scopes.contains($0.scope) && $0.plannerVisible }.sorted { $0.name < $1.name }
    }

    /// 등록된 도구 전체를 읽기 전용으로 반환한다.
    var allTools: [WorkflowTool] {
        tools.values.sorted { $0.name < $1.name }
    }

    /// planner-visible 도구만 반환한다.
    func plannerVisibleTools(for scopes: Set<ToolScope>? = nil) -> [WorkflowTool] {
        let list: [WorkflowTool]
        if let scopes {
            list = tools.values.filter { scopes.contains($0.scope) && $0.plannerVisible }
        } else {
            list = tools.values.filter { $0.plannerVisible }
        }
        return list.sorted { $0.name < $1.name }
    }

    var hiddenStubToolCount: Int {
        tools.values.filter { !$0.plannerVisible && $0.availability != .available }.count
    }

    func plannerVisibleToolCount(for scopes: Set<ToolScope>? = nil) -> Int {
        plannerVisibleTools(for: scopes).count
    }

    /// 도구 이름 조회용 read-only helper.
    func tool(named name: String) -> WorkflowTool? {
        lookup(name: name)
    }

    /// LLM 플래너 프롬프트에 포함할 도구 스키마 설명 (scope 필터 지원)
    func toolSchemaDescription(for scopes: Set<ToolScope>? = nil) -> String {
        let list = plannerVisibleTools(for: scopes)
        return list.map { tool in
            let params = tool.inputSchema
                .sorted { $0.key < $1.key }
                .map { "  - \($0.key): \($0.value)" }
                .joined(separator: "\n")
            return "- \(tool.name) [\(tool.riskLevel.rawValue)]: \(tool.description)\n\(params)"
        }.joined(separator: "\n")
    }

    /// 하위 호환: scope 없이 전체 반환 (deprecated 경고로 표시)
    @available(*, deprecated, message: "Use toolSchemaDescription(for:) with explicit scopes")
    var toolSchemaDescription: String { toolSchemaDescription(for: nil) }
}
