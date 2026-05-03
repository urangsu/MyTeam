import Foundation

// MARK: - Tool Risk Level

enum ToolRiskLevel: String, Codable, Hashable {
    case safe        // 읽기 전용, 외부 부작용 없음
    case moderate    // 파일 생성/수정 등 로컬 부작용
    case high        // 외부 API 호출, 시스템 설정 변경
    case destructive // 삭제, 불가역 작업 — MVP에서 실행 금지
}

// MARK: - Tool Input / Result

struct ToolInput {
    let parameters: [String: String]
    subscript(key: String) -> String? { parameters[key] }
}

struct ToolResult {
    let success: Bool
    let output: String
    let artifactPath: String?  // Workspace 내 상대 경로
    let error: String?

    static func failure(_ message: String) -> ToolResult {
        ToolResult(success: false, output: "", artifactPath: nil, error: message)
    }
}

// MARK: - Tool Errors

enum ToolError: Error, LocalizedError {
    case forbidden(String)
    case invalidInput(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .forbidden(let m):       return "접근 거부: \(m)"
        case .invalidInput(let m):    return "입력 오류: \(m)"
        case .executionFailed(let m): return "실행 실패: \(m)"
        }
    }
}

// MARK: - WorkflowTool Protocol
// AgentToolKit.swift의 AgentTool(struct)과 구분하기 위해 WorkflowTool로 명명.

protocol WorkflowTool {
    var name: String { get }
    var description: String { get }
    var riskLevel: ToolRiskLevel { get }
    /// paramName → 설명 (LLM 플래너에게 노출)
    var inputSchema: [String: String] { get }
    func execute(input: ToolInput, context: ToolExecutionContext) async throws -> ToolResult
}

// MARK: - Shared path-safety helper

func safeWorkspaceURL(filename: String, context: ToolExecutionContext) throws -> URL {
    let clean = (filename as NSString).lastPathComponent
    guard !clean.isEmpty, !clean.hasPrefix("."), clean == filename else {
        throw ToolError.forbidden("경로 탐색 금지 (../): \(filename)")
    }
    let target = context.workspaceURL.appendingPathComponent(clean)
    guard target.path.hasPrefix(context.workspaceURL.path) else {
        throw ToolError.forbidden("Workspace 외부 접근 금지: \(filename)")
    }
    return target
}
