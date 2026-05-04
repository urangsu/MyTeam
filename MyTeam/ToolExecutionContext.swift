import Foundation

// MARK: - ToolExecutionContext

struct ToolExecutionContext {
    let workspaceURL: URL
    /// 이번 workflow의 UUID (WorkflowRunStore / AgentEventStream 연결 키)
    let workflowID: UUID
    /// 응답을 기록할 roomID (WorkflowRunStore 기록에 사용)
    let roomID: UUID
    let isDryRun: Bool

    /// 하위 호환용 String sessionID (WorkflowEngine 내 ArtifactIndex에 사용)
    var sessionID: String { workflowID.uuidString }

    /// workspace 경로만 필요한 진단/읽기 전용 컨텍스트 (roomID 불필요 시)
    static var workspaceURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = appSupport.appendingPathComponent("MyTeam/Workspace")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 현재 세션의 컨텍스트를 생성한다.
    /// Workspace 폴더: ~/Library/Application Support/MyTeam/Workspace/
    static func current(
        workflowID: UUID = UUID(),
        roomID: UUID,
        isDryRun: Bool = false
    ) -> ToolExecutionContext {
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
            workflowID: workflowID,
            roomID: roomID,
            isDryRun: isDryRun
        )
    }
}
