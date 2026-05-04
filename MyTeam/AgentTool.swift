import Foundation

// MARK: - Tool Risk Level

enum ToolRiskLevel: String, Codable, Hashable {
    case safe        // 읽기 전용, 외부 부작용 없음
    case moderate    // 파일 생성/수정 등 로컬 부작용
    case high        // 외부 API 호출, 시스템 설정 변경
    case destructive // 삭제, 불가역 작업 — MVP에서 실행 금지
}

// MARK: - Tool Scope
// 요청 유형별로 필요한 tool만 LLM에 노출.
// 기본 노출 금지 항목: Accessibility, global input, shell 계열.

enum ToolScope: String, CaseIterable {
    case chatBasic          // 읽기·요약·URL 열기 (기본 채팅)
    case artifactGeneration // 파일/PPT/XLSX 생성
    case documentEditing    // 기존 파일 편집
    case browserDOM         // 브라우저 DOM 조작 (명시적 활성화 필요)
    case officeLive         // 오피스 앱 live bridge (명시적 활성화 필요)
    case schedule           // 스케줄 관리
    case diagnostics        // 런타임 진단 (내부 전용)
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
    /// 이 도구가 속하는 scope — 기본 chatBasic
    var scope: ToolScope { get }
    /// paramName → 설명 (LLM 플래너에게 노출)
    var inputSchema: [String: String] { get }
    func execute(input: ToolInput, context: ToolExecutionContext) async throws -> ToolResult
}

extension WorkflowTool {
    /// scope를 선언하지 않은 기존 도구는 chatBasic 기본값 사용
    var scope: ToolScope { .chatBasic }
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
