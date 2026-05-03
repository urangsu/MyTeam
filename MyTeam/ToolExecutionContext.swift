import Foundation

// MARK: - ToolExecutionContext

struct ToolExecutionContext {
    let workspaceURL: URL
    let sessionID: String
    let isDryRun: Bool

    /// 현재 세션의 컨텍스트를 생성한다.
    /// Workspace 폴더: ~/Library/Application Support/MyTeam/Workspace/
    static func current(isDryRun: Bool = false) -> ToolExecutionContext {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let workspaceURL = appSupport.appendingPathComponent("MyTeam/Workspace")
        try? FileManager.default.createDirectory(
            at: workspaceURL,
            withIntermediateDirectories: true
        )
        return ToolExecutionContext(
            workspaceURL: workspaceURL,
            sessionID: UUID().uuidString,
            isDryRun: isDryRun
        )
    }
}
