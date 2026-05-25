import Foundation

// MARK: - TeamRuntimeStatusCopy
// Round 278 1-F: TeamRuntimeState → 사용자에게 보여줄 한 줄 한국어 변환.
// UI(WorkflowProgressIndicatorView)가 이 함수만 호출하면 어떤 단계인지 한 줄로 표현됨.
// Claude의 "Thinking…", ChatGPT의 회전 점, Gemini의 펄스에 해당하는 "동작 중" 텍스트.

enum TeamRuntimeStatusCopy {

    /// 인디케이터에 표시할 한 줄 텍스트. nil 반환 시 인디케이터 숨김.
    static func text(for state: TeamRuntimeState?) -> String? {
        guard let state = state, state.isActive else { return nil }
        switch state.kind {
        case .discussionStarted:
            return "팀이 작업을 시작합니다…"
        case .selectingSpeaker:
            return "다음 발언자를 정하고 있어요…"
        case .speakerSelected, .fallbackSpeakerSelected:
            if let name = state.agentName {
                return "\(name) 준비 중…"
            }
            return "담당자 준비 중…"
        case .agentTurnStarted:
            if let name = state.agentName {
                let trimmed = state.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return "\(name) 작성 중: \(trimmed)"
                }
                return "\(name) 작성 중…"
            }
            return "응답 작성 중…"
        case .agentTurnCompleted, .discussionCompleted, .discussionFailed, .idle:
            return nil
        }
    }

    /// 인디케이터 색상 결정용 에이전트 이름 (nil이면 시스템 색).
    static func agentName(for state: TeamRuntimeState?) -> String? {
        guard let state = state, state.isActive else { return nil }
        return state.agentName
    }

    /// `manager.workflowStatusText`가 있으면 우선 사용, 없으면 teamRuntimeState에서 추론.
    /// WorkflowOrchestrator(단일 작업)와 TeamOrchestrator(팀 협업) 두 경로를 모두 커버.
    static func displayText(workflowStatusText: String?, teamState: TeamRuntimeState?) -> String? {
        if let wf = workflowStatusText, !wf.isEmpty {
            return wf
        }
        return text(for: teamState)
    }

    // MARK: - Round 278 1-F: WorkflowOrchestrator step key → 한글 매핑
    // updateRoomGoalContext(activeWorkflowStep:)에서 자동 변환됨.
    // 알 수 없는 key는 nil 반환 → 인디케이터는 teamRuntimeState로 fallback.
    static func koreanStatus(forWorkflowStep step: String?) -> String? {
        guard let step = step else { return nil }
        switch step {
        case "routing":                              return "요청을 분석하고 있어요…"
        case "directChatFallback":                   return "응답을 준비하고 있어요…"
        case "recentArtifactReuse.detected":         return "최근 결과물을 다시 활용할 수 있는지 확인 중…"
        case "localSchedulerDocumentBridge.detected": return "스케줄 정보를 가져오고 있어요…"
        case "dailyBriefing.preparing":              return "오늘 브리핑을 준비하고 있어요…"
        case "dailyBriefing.completed":              return nil   // 완료 → 인디케이터 숨김
        case "fileIntake.documentRequested":         return "파일을 읽고 있어요…"
        case "universalDocument.detected":           return "문서 작업을 준비하고 있어요…"
        case "universalDocument.clarify":            return "필요한 정보를 정리하고 있어요…"
        case "universalDocument.generating":         return "초안을 작성하고 있어요…"
        case "universalDocument.verifying":          return "결과물을 검토하고 있어요…"
        case "universalDocument.saving":             return "파일로 저장하고 있어요…"
        case "universalDocument.blocked",
             "universalDocument.failed",
             "universalDocument.cancelled":          return nil   // 종료 상태
        case "planRunner.started":                   return "작업 계획을 준비하고 있어요…"
        case "planRunner.generating":                return "초안을 작성하고 있어요…"
        case "planRunner.verifying":                 return "결과물을 검토하고 있어요…"
        case "planRunner.saving":                    return "파일로 저장하고 있어요…"
        default:                                     return nil
        }
    }
}
