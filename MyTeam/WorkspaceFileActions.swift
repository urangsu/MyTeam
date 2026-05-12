import Foundation
import AppKit

// MARK: - WorkspaceFileActions

enum WorkspaceFileActions {
    static func revealInFinder(path: String) -> Result<Void, FileActionError> {
        guard !path.isEmpty else { return .failure(.pathEmpty) }
        guard isInsideWorkspace(path) else { return .failure(.pathOutsideWorkspace) }
        guard FileManager.default.fileExists(atPath: path) else { return .failure(.fileNotFound) }

        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        return .success(())
    }

    static func copyPathToPasteboard(path: String) -> Result<Void, FileActionError> {
        guard !path.isEmpty else { return .failure(.pathEmpty) }
        guard isInsideWorkspace(path) else { return .failure(.pathOutsideWorkspace) }
        guard FileManager.default.fileExists(atPath: path) else { return .failure(.fileNotFound) }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
        return .success(())
    }

    static func isInsideWorkspace(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        let workspaceURL = ArtifactStore.shared.workspaceURL
        let testURL = URL(fileURLWithPath: path)
        return testURL.path.hasPrefix(workspaceURL.path)
    }

    // MARK: - Error

    enum FileActionError: Error {
        case pathEmpty
        case pathOutsideWorkspace
        case fileNotFound

        var message: String {
            switch self {
            case .pathEmpty:
                return "경로가 비어있습니다."
            case .pathOutsideWorkspace:
                return "Workspace 내부 파일만 열 수 있습니다."
            case .fileNotFound:
                return "파일을 찾을 수 없습니다. Workspace에서 다시 확인해 주세요."
            }
        }
    }
}

// MARK: - Workspace UI Tools

enum WorkspaceFileActionKind {
    case revealInFinder
    case copyPath
}

struct WorkspaceRevealFileTool: WorkflowTool {
    let name = "workspace_reveal_in_finder"
    let description = "Workspace 내부 파일을 Finder에서 표시한다"
    let riskLevel: ToolRiskLevel = .safe
    let scope: ToolScope = .localUI
    let plannerVisible: Bool = false
    let availability: ToolAvailability = .available
    let inputSchema: [String: String] = [
        "path": "Workspace 내부 절대 경로"
    ]

    func execute(input: ToolInput, context: ToolExecutionContext) async throws -> ToolResult {
        guard let path = input["path"] else {
            throw ToolError.invalidInput("path 필수")
        }
        switch WorkspaceFileActions.revealInFinder(path: path) {
        case .success:
            return ToolResult(status: .succeeded, output: "Finder에서 열었습니다.", artifactPath: path, error: nil)
        case .failure(let error):
            return ToolResult(status: .blocked, output: "", artifactPath: nil, error: error.message)
        }
    }
}

struct WorkspaceCopyPathTool: WorkflowTool {
    let name = "workspace_copy_path"
    let description = "Workspace 내부 파일의 경로를 복사한다"
    let riskLevel: ToolRiskLevel = .safe
    let scope: ToolScope = .localUI
    let plannerVisible: Bool = false
    let availability: ToolAvailability = .available
    let inputSchema: [String: String] = [
        "path": "Workspace 내부 절대 경로"
    ]

    func execute(input: ToolInput, context: ToolExecutionContext) async throws -> ToolResult {
        guard let path = input["path"] else {
            throw ToolError.invalidInput("path 필수")
        }
        switch WorkspaceFileActions.copyPathToPasteboard(path: path) {
        case .success:
            return ToolResult(status: .succeeded, output: "경로를 복사했습니다.", artifactPath: path, error: nil)
        case .failure(let error):
            return ToolResult(status: .blocked, output: "", artifactPath: nil, error: error.message)
        }
    }
}
