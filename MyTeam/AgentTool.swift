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

enum ToolScope: String, Codable, CaseIterable {
    case chatBasic          // 읽기·요약·URL 열기 (기본 채팅)
    case workspaceRead      // Workspace 파일 읽기
    case artifactGeneration // 파일/PPT/XLSX 생성
    case documentEditing    // 기존 파일 편집
    case localUI            // Finder / pasteboard 같은 사용자 주도 로컬 UI 액션
    case browserDOM         // 브라우저 DOM 조작 (명시적 활성화 필요)
    case officeLive         // 오피스 앱 live bridge (명시적 활성화 필요)
    case schedule           // 스케줄 관리
    case diagnostics        // 런타임 진단 (내부 전용)
}

enum ToolAvailability: String, Codable, Equatable {
    case available
    case future
    case requiresApproval
    case unavailable
    case blocked
}

// MARK: - Tool Input / Result

struct ToolInput: Sendable {
    let parameters: [String: String]
    subscript(key: String) -> String? { parameters[key] }
}

struct ToolResult: Sendable {
    let status: ToolResultStatus
    let output: String
    let artifactPath: String?  // Workspace 내 상대 경로
    let error: String?

    var success: Bool {
        status == .succeeded
    }

    nonisolated init(
        status: ToolResultStatus,
        output: String,
        artifactPath: String?,
        error: String?
    ) {
        self.status = status
        self.output = output
        self.artifactPath = artifactPath
        self.error = error
    }

    @available(*, deprecated, message: "Use init(status:output:artifactPath:error:) so the result status stays explicit.")
    nonisolated init(
        success: Bool,
        output: String,
        artifactPath: String?,
        error: String?
    ) {
        self.init(
            status: success ? .succeeded : .failed,
            output: output,
            artifactPath: artifactPath,
            error: error
        )
    }

    nonisolated static func failure(_ message: String) -> ToolResult {
        ToolResult(status: .failed, output: "", artifactPath: nil, error: message)
    }
}

enum ToolResultStatus: String, Codable, Equatable {
    case succeeded
    case failed
    case blocked
    case dryRun
    case cancelled
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

protocol WorkflowTool: Sendable {
    // nonisolated: these properties must be accessible from any actor context
    nonisolated var name: String { get }
    nonisolated var description: String { get }
    nonisolated var riskLevel: ToolRiskLevel { get }
    /// 이 도구가 속하는 scope — 기본 chatBasic
    nonisolated var scope: ToolScope { get }
    /// planner-visible surface에서 노출할지 여부. stub / localUI tool은 false 가능.
    nonisolated var plannerVisible: Bool { get }
    /// 실행 가능성. stub tool이나 아직 연결되지 않은 tool은 available이 아닐 수 있다.
    nonisolated var availability: ToolAvailability { get }
    /// Release에서 planner-visible이면 안 되는 디버그 전용 도구 여부.
    nonisolated var debugOnly: Bool { get }
    /// 장기 기억/UserDefaults에 쓰는 도구 여부.
    nonisolated var writesMemory: Bool { get }
    /// 메모리 저장을 수행하는 경우 필요한 retention policy.
    nonisolated var memorySensitivityPolicy: MemoryRetentionPolicy? { get }
    /// 연결/외부 write 계열 도구가 승인 정책을 명시했는지 여부.
    nonisolated var requiresApprovalPolicy: Bool { get }
    /// paramName → 설명 (LLM 플래너에게 노출)
    nonisolated var inputSchema: [String: String] { get }
    func execute(input: ToolInput, context: ToolExecutionContext) async throws -> ToolResult
}

extension WorkflowTool {
    nonisolated var plannerVisible: Bool { true }
    nonisolated var availability: ToolAvailability { .available }
    nonisolated var debugOnly: Bool { false }
    nonisolated var writesMemory: Bool { false }
    nonisolated var memorySensitivityPolicy: MemoryRetentionPolicy? { nil }
    nonisolated var requiresApprovalPolicy: Bool { false }
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

func safeWritableWorkspaceURL(filename: String, context: ToolExecutionContext) throws -> URL {
    let clean = (filename as NSString).lastPathComponent
    guard !clean.isEmpty, !clean.hasPrefix("."), clean == filename else {
        throw ToolError.forbidden("경로 탐색 금지 (../): \(filename)")
    }

    let workspaceURL = context.workspaceURL
    let baseURL = workspaceURL.appendingPathComponent(clean)
    guard baseURL.path.hasPrefix(workspaceURL.path) else {
        throw ToolError.forbidden("Workspace 외부 접근 금지: \(filename)")
    }

    if !FileManager.default.fileExists(atPath: baseURL.path) {
        return baseURL
    }

    let directory = baseURL.deletingLastPathComponent()
    let stem = baseURL.deletingPathExtension().lastPathComponent
    let ext = baseURL.pathExtension
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd-HHmm"
    let stamp = formatter.string(from: Date())

    var candidate = directory.appendingPathComponent(ext.isEmpty ? "\(stem)-\(stamp)" : "\(stem)-\(stamp).\(ext)")
    var suffix = 2
    while FileManager.default.fileExists(atPath: candidate.path) {
        candidate = directory.appendingPathComponent(ext.isEmpty ? "\(stem)-\(stamp)-\(suffix)" : "\(stem)-\(stamp)-\(suffix).\(ext)")
        suffix += 1
    }
    return candidate
}
