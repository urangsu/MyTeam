import Foundation

// MARK: - Notification 이름 정의
// FloatingPanel ↔ TeamTableView 드래그 상태 통신용
extension Notification.Name {
    static let agentDragBegan = Notification.Name("agentDragBegan")
    static let agentDragEnded = Notification.Name("agentDragEnded")
}
