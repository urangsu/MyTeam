import Foundation

// MARK: - PendingApprovalStore
// Round 246B-ACTION: 승인 필요 작업을 room-scoped로 보관.
//
// 정책:
// - 모든 approval request는 반드시 roomID를 가진다.
// - 다른 방의 approval request는 보이지 않는다.
// - 승인 요청은 자동 실행하지 않는다.
// - 246B: approve/reject 상태 변경까지.
// - 실제 재실행(diff preview, original write)은 이후 라운드에서 연결.
// - expiresAt이 지난 request는 expired 처리.

@MainActor
final class PendingApprovalStore: ObservableObject {

    static let shared = PendingApprovalStore()
    private init() {}

    @Published private(set) var requestsByRoomID: [UUID: [PendingApprovalRequest]] = [:]

    // MARK: - Write

    func add(_ request: PendingApprovalRequest) {
        var list = requestsByRoomID[request.roomID, default: []]
        // 중복 방지
        if !list.contains(where: { $0.id == request.id }) {
            list.append(request)
        }
        requestsByRoomID[request.roomID] = list
        AppLog.info("[ApprovalStore] added request \(request.id) room=\(request.roomID) tool=\(request.toolName)")
    }

    func approve(_ requestID: UUID, roomID: UUID) {
        update(requestID: requestID, roomID: roomID, newStatus: .approved)
        AppLog.info("[ApprovalStore] approved \(requestID)")
    }

    func reject(_ requestID: UUID, roomID: UUID) {
        update(requestID: requestID, roomID: roomID, newStatus: .rejected)
        AppLog.info("[ApprovalStore] rejected \(requestID)")
    }

    /// 만료된 요청 처리
    func expireOldRequests(now: Date = Date()) {
        for roomID in requestsByRoomID.keys {
            requestsByRoomID[roomID] = requestsByRoomID[roomID]?.map { req in
                guard req.status == .pending,
                      let expiresAt = req.expiresAt,
                      now > expiresAt else { return req }
                var expired = req
                expired.status = .expired
                return expired
            }
        }
    }

    func clear(roomID: UUID) {
        requestsByRoomID.removeValue(forKey: roomID)
    }

    // MARK: - Read

    func requests(for roomID: UUID) -> [PendingApprovalRequest] {
        expireOldRequests()
        return requestsByRoomID[roomID] ?? []
    }

    func pendingRequests(for roomID: UUID) -> [PendingApprovalRequest] {
        requests(for: roomID).filter { $0.status == .pending }
    }

    func hasPending(for roomID: UUID) -> Bool {
        !pendingRequests(for: roomID).isEmpty
    }

    // MARK: - Private

    private func update(requestID: UUID, roomID: UUID, newStatus: ApprovalStatus) {
        guard var list = requestsByRoomID[roomID] else { return }
        for i in list.indices where list[i].id == requestID {
            list[i].status = newStatus
        }
        requestsByRoomID[roomID] = list
    }
}
