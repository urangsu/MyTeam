import Foundation

// MARK: - Notification 이름 정의
// FloatingPanel ↔ TeamTableView 드래그 상태 통신용
extension Notification.Name {
    static let agentDragBegan = Notification.Name("agentDragBegan")
    static let agentDragEnded = Notification.Name("agentDragEnded")
    static let characterEmote = Notification.Name("characterEmote")
    /// WorkflowEngine 완료 시 발송. userInfo["workspaceURL"] = URL
    static let workflowCompleted = Notification.Name("MyTeam.workflowCompleted")
}
