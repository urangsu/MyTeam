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
