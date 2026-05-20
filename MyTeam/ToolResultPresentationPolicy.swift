import Foundation

// MARK: - ToolResultPresentation
// Round 246B-ACTION: ToolResult.status → 사용자 경험 매핑.
//
// 정책 요약:
// - .succeeded/.dryRun/.cancelled → normalMessage
// - .planned/.unavailable → plannedNotice/unavailableNotice + fallbackDirectChat 옵션
// - .approvalRequired → approvalRequired(PendingApprovalRequest)
// - .blocked → hardBlock (payment/login/delete만 진짜 hard block)
// - .failed → normalMessage(error) 또는 fallbackDirectChat
//
// planned/unavailable은 단순 종료하지 않는다.
// 가능하면 directChat fallback을 제공한다.

enum ToolResultPresentation {
    case normalMessage(String)
    case approvalRequired(PendingApprovalRequest)
    case plannedNotice(String)
    case unavailableNotice(String)
    case hardBlock(String)
    case fallbackDirectChat(String)
}

enum ToolResultPresentationPolicy {

    static func presentation(
        for result: ToolResult,
        toolName: String,
        roomID: UUID,
        input: ToolInput
    ) -> ToolResultPresentation {
        switch result.status {

        case .succeeded:
            return .normalMessage(result.output)

        case .dryRun:
            return .normalMessage(result.output.isEmpty
                ? "[\(toolName)] dry-run 완료"
                : result.output)

        case .cancelled:
            return .normalMessage("작업이 취소됐습니다.")

        case .failed:
            let msg = result.error ?? "도구 실행 중 문제가 발생했습니다."
            // failed는 fallbackDirectChat 가능 — 사용자에게 대체 도움 제공
            return .fallbackDirectChat("도구 실행 중 문제가 발생했습니다. 다른 방법으로 도와드릴게요. (\(msg))")

        case .planned:
            let msg = result.error ?? "아직 준비 중인 기능입니다."
            return .plannedNotice(msg)

        case .unavailable:
            let msg = result.error ?? "현재 사용할 수 없는 상태입니다."
            return .unavailableNotice(msg)

        case .approvalRequired:
            let request = PendingApprovalRequest(
                id: UUID(),
                roomID: roomID,
                toolName: toolName,
                input: input.parameters,
                riskLevel: .high,
                reason: result.error ?? "이 작업은 실행 전 확인이 필요합니다: \(toolName)",
                createdAt: Date(),
                expiresAt: Calendar.current.date(byAdding: .hour, value: 24, to: Date()),
                status: .pending
            )
            return .approvalRequired(request)

        case .blocked:
            let msg = result.error ?? "이 작업은 안전 정책상 실행할 수 없습니다."
            return .hardBlock(msg)
        }
    }

    // MARK: - User-visible messages

    static let plannedFallbackMessage =
        "아직 직접 실행은 준비 중입니다. 대신 지금 가능한 범위에서 정리해드릴게요."

    static let unavailableFallbackMessage =
        "현재 실행할 수 없는 상태입니다. 자료를 주시면 초안/검토 형태로 도와드릴 수 있어요."

    static let approvalRequiredFallbackMessage =
        "이 작업은 실행 전 확인이 필요합니다. 먼저 초안 또는 실행 전 미리보기를 보여드릴게요."

    static let blockedFallbackMessage =
        "이 작업은 안전 정책상 실행할 수 없습니다. 대신 안전한 대체 방법을 안내해드릴게요."
}
