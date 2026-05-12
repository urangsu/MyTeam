import Foundation

@MainActor
enum LocalSchedulerDocumentBridge {
    nonisolated static func targetType(for command: LocalSchedulerCommand) -> UniversalDocumentSkillType? {
        switch command.kind {
        case .buildTodayScheduleReport:
            return .reportDraft
        case .buildTodayScheduleChecklist:
            return .checklist
        case .summarizePendingApprovalsDocument, .summarizeDelegatedWorkDocument:
            return .actionItems
        default:
            return nil
        }
    }

    static func makeRequest(
        command: LocalSchedulerCommand,
        roomID: UUID,
        manager: AgentWindowManager,
        targetType: UniversalDocumentSkillType
    ) -> UniversalDocumentSkillRequest? {
        let sourceText = buildSourceText(for: command, roomID: roomID, manager: manager)
        guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let sourceName = sourceName(for: command)
        return UniversalDocumentSkillService.extractRequest(
            from: command.sourceMessage,
            type: targetType,
            sourceText: sourceText,
            sourceName: sourceName
        )
    }

    private static func sourceName(for command: LocalSchedulerCommand) -> String {
        switch command.kind {
        case .buildTodayScheduleReport:
            return "오늘 스케줄"
        case .buildTodayScheduleChecklist:
            return "오늘 업무"
        case .summarizePendingApprovalsDocument:
            return "승인 대기 목록"
        case .summarizeDelegatedWorkDocument:
            return "위임 작업"
        default:
            return "로컬 스케줄"
        }
    }

    private static func buildSourceText(
        for command: LocalSchedulerCommand,
        roomID: UUID,
        manager: AgentWindowManager
    ) -> String {
        let tasks = todayTasks(roomID: roomID, manager: manager)
        let pendingApprovals = tasks.filter { manager.pendingApprovalTaskIDs.contains($0.id) }
        let delegated = manager.pendingDelegatedExecutionRequest(for: roomID)
        var lines: [String] = []

        switch command.kind {
        case .buildTodayScheduleReport:
            lines.append("오늘 스케줄 업무 보고서 초안")
            lines.append("")
            for task in tasks.prefix(8) {
                let agentName = agentName(for: task.assignedAgentID, manager: manager)
                lines.append("- \(timeString(task.nextRunAt)) \(agentName) — \(task.title) [\(task.requiresApproval ? "승인 필요" : "자동")]")
            }
            if !pendingApprovals.isEmpty {
                lines.append("")
                lines.append("승인 대기")
                for task in pendingApprovals.prefix(5) {
                    lines.append("- \(timeString(task.nextRunAt)) \(task.title)")
                }
            }
        case .buildTodayScheduleChecklist:
            lines.append("오늘 업무 체크리스트")
            lines.append("")
            for task in tasks.prefix(8) {
                let agentName = agentName(for: task.assignedAgentID, manager: manager)
                lines.append("- [ ] \(timeString(task.nextRunAt)) \(agentName) — \(task.title)")
            }
        case .summarizePendingApprovalsDocument:
            lines.append("승인 대기 목록")
            lines.append("")
            if pendingApprovals.isEmpty {
                lines.append("- 승인 대기 작업이 없습니다.")
            } else {
                for task in pendingApprovals.prefix(8) {
                    lines.append("- \(timeString(task.nextRunAt)) \(task.title)")
                }
            }
        case .summarizeDelegatedWorkDocument:
            lines.append("위임 작업 목록")
            lines.append("")
            if let delegated {
                lines.append("- 상태: \(delegated.status.rawValue)")
                lines.append("- 승인 대기 여부: \(delegated.status == .pendingApproval ? "예" : "아니오")")
            } else {
                lines.append("- 진행 중인 위임 작업이 없습니다.")
            }
        default:
            break
        }

        return lines.joined(separator: "\n")
    }

    private static func todayTasks(roomID: UUID, manager: AgentWindowManager) -> [AgentWindowManager.AutomationTask] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        return manager.automationTasks
            .filter { task in
                guard task.isEnabled else { return false }
                if let taskRoomID = task.roomID, taskRoomID != roomID { return false }
                return task.nextRunAt >= today && task.nextRunAt < tomorrow
            }
            .sorted { $0.nextRunAt < $1.nextRunAt }
    }

    private static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private static func agentName(for agentID: String?, manager: AgentWindowManager) -> String {
        guard let agentID else { return "시스템" }
        return manager.activeAgents.first(where: { $0.id == agentID })?.name ?? agentID
    }
}
