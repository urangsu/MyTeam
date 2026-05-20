import SwiftUI

// MARK: - PendingApprovalBannerView
// Round 246B-ACTION: 현재 room에 pending approval이 있을 때 composer 위에 표시하는 배너.
//
// 정책:
// - 0건이면 숨김
// - 팀 워크룸 pending은 팀 워크룸에만
// - 개인 대화 pending은 해당 방에만
// - 다른 방 approval은 보이지 않음

struct PendingApprovalBannerView: View {
    let roomID: UUID
    @ObservedObject var approvalStore: PendingApprovalStore

    @State private var showDetail: Bool = false

    private var pendingRequests: [PendingApprovalRequest] {
        approvalStore.pendingRequests(for: roomID)
    }

    var body: some View {
        if !pendingRequests.isEmpty {
            VStack(spacing: 0) {
                // Banner strip
                Button(action: { showDetail.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)

                        Text(bannerText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: showDetail ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.orange.opacity(0.08))
                }
                .buttonStyle(.plain)

                // Detail cards (expanded)
                if showDetail {
                    VStack(spacing: 6) {
                        ForEach(pendingRequests, id: \.id) { request in
                            ApprovalRequiredCardView(
                                request: request,
                                onApprove: { id in
                                    approvalStore.approve(id, roomID: roomID)
                                },
                                onReject: { id in
                                    approvalStore.reject(id, roomID: roomID)
                                },
                                onDraftOnly: { toolName in
                                    // directChat fallback 요청 — 부모 뷰에서 처리
                                    NotificationCenter.default.post(
                                        name: .approvalDraftOnlyRequested,
                                        object: nil,
                                        userInfo: [
                                            "roomID": roomID,
                                            "toolName": toolName,
                                            "requestID": request.id
                                        ]
                                    )
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                    .background(Color.orange.opacity(0.04))
                }
            }
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.orange.opacity(0.2)),
                alignment: .bottom
            )
        }
    }

    private var bannerText: String {
        let count = pendingRequests.count
        return count == 1
            ? "실행 전 확인이 필요한 작업 1건"
            : "실행 전 확인이 필요한 작업 \(count)건"
    }
}

// MARK: - Notification

extension Notification.Name {
    static let approvalDraftOnlyRequested = Notification.Name("approvalDraftOnlyRequested")
}

// MARK: - Preview

#if DEBUG
struct PendingApprovalBannerView_Previews: PreviewProvider {
    static var previews: some View {
        let store = PendingApprovalStore.shared
        let roomID = UUID()
        let _ = Task { @MainActor in
            store.add(PendingApprovalRequest(
                id: UUID(),
                roomID: roomID,
                toolName: "calendarCreate",
                input: ["title": "팀 회의"],
                riskLevel: .high,
                reason: "이 작업은 실행 전 확인이 필요합니다: calendarCreate",
                createdAt: Date(),
                expiresAt: nil,
                status: .pending
            ))
        }
        return PendingApprovalBannerView(roomID: roomID, approvalStore: store)
            .frame(width: 320)
    }
}
#endif
