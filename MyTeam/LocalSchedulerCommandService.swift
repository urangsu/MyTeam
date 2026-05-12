import Foundation

@MainActor
enum LocalSchedulerCommandService {
    static func response(
        for command: LocalSchedulerCommand,
        roomID: UUID,
        manager: AgentWindowManager
    ) -> String {
        switch command.kind {
        case .openSchedulePanel:
            return "스케줄 패널을 열겠습니다."

        case .showTodaySchedule:
            return buildTodayScheduleResponse(roomID: roomID, manager: manager)

        case .showPendingApprovals:
            return buildPendingApprovalsResponse(roomID: roomID, manager: manager)

        case .summarizeRemainingWork:
            return buildRemainingWorkSummary(roomID: roomID, manager: manager)

        case .summarizeScheduleBasedTasks:
            return buildScheduleBasedTasksSummary(roomID: roomID, manager: manager)

        case .showDelegatedWork:
            return buildDelegatedWorkResponse(roomID: roomID, manager: manager)

        case .showSchedulePolicy:
            return buildSchedulePolicyResponse()

        case .buildTodayScheduleReport:
            return "오늘 스케줄 기준 보고서 초안을 만들 수 있습니다."

        case .buildTodayScheduleChecklist:
            return "오늘 업무 체크리스트 초안을 만들 수 있습니다."

        case .summarizePendingApprovalsDocument:
            return "승인 대기 목록을 문서로 정리할 수 있습니다."

        case .summarizeDelegatedWorkDocument:
            return "위임 작업을 문서로 정리할 수 있습니다."
        }
    }

    private static func buildTodayScheduleResponse(roomID: UUID, manager: AgentWindowManager) -> String {
        let tasks = getTodayTasks(roomID: roomID, manager: manager)
            .filter { $0.isEnabled }
            .sorted { ($0.nextRunAt) < ($1.nextRunAt) }

        guard !tasks.isEmpty else {
            return "오늘 등록된 로컬 스케줄 업무가 없습니다."
        }

        var output = "# 오늘 로컬 스케줄\n\n"
        output += "## 예정된 작업\n"

        for task in tasks {
            let agentName = getAgentName(task.assignedAgentID, manager: manager)
            let time = formatTime(task.nextRunAt)
            output += "- \(time) \(agentName) — \(task.title)\n"
        }

        let pendingCount = tasks.filter { manager.pendingApprovalTaskIDs.contains($0.id) }.count

        if pendingCount > 0 {
            output += "\n## 승인 대기\n"
            output += "- 승인 대기 작업 \(pendingCount)건\n"
        }

        output += "\n## 다음 액션\n"
        if pendingCount > 0 {
            output += "- \"승인 대기 보여줘\"로 대기 중인 작업을 확인할 수 있습니다.\n"
        }

        return output
    }

    private static func buildPendingApprovalsResponse(roomID: UUID, manager: AgentWindowManager) -> String {
        let tasks = getTodayTasks(roomID: roomID, manager: manager)
            .filter { $0.isEnabled && manager.pendingApprovalTaskIDs.contains($0.id) }
            .sorted { $0.nextRunAt < $1.nextRunAt }

        guard !tasks.isEmpty else {
            return "현재 승인 대기 작업이 없습니다."
        }

        var output = "# 승인 대기 작업\n\n"

        for task in tasks {
            let agentName = getAgentName(task.assignedAgentID, manager: manager)
            let time = formatTime(task.nextRunAt)
            output += "- [\(time)] \(agentName): \(task.title)\n"
        }

        output += "\n자동 승인이나 자동 실행은 하지 않습니다.\n"

        return output
    }

    private static func buildRemainingWorkSummary(roomID: UUID, manager: AgentWindowManager) -> String {
        let tasks = getTodayTasks(roomID: roomID, manager: manager)
            .filter { $0.isEnabled }

        guard !tasks.isEmpty else {
            return "오늘 남은 업무가 없습니다."
        }

        var output = "# 오늘 남은 업무\n\n"
        output += "- 남은 스케줄 작업 \(tasks.count)건\n"

        let pending = tasks.filter { manager.pendingApprovalTaskIDs.contains($0.id) }
        if !pending.isEmpty {
            output += "- 승인 대기 \(pending.count)건\n"
        }

        return output
    }

    private static func buildScheduleBasedTasksSummary(roomID: UUID, manager: AgentWindowManager) -> String {
        let tasks = getTodayTasks(roomID: roomID, manager: manager)
            .filter { $0.isEnabled }
            .sorted { $0.nextRunAt < $1.nextRunAt }

        guard !tasks.isEmpty else {
            return "오늘 등록된 스케줄 업무가 없습니다."
        }

        var output = "# 오늘 스케줄 기준 할 일\n\n"

        let grouped = Dictionary(grouping: tasks) { task in
            formatTime(task.nextRunAt)
        }

        for (time, taskList) in grouped.sorted(by: { $0.key < $1.key }) {
            output += "## \(time)\n"
            for task in taskList.sorted(by: { $0.nextRunAt < $1.nextRunAt }) {
                let agentName = getAgentName(task.assignedAgentID, manager: manager)
                output += "- [\(agentName)] \(task.title)\n"
            }
            output += "\n"
        }

        return output
    }

    private static func buildDelegatedWorkResponse(roomID: UUID, manager: AgentWindowManager) -> String {
        // Delegation state is not yet fully implemented in the current version
        // Return a placeholder response
        return "현재 진행 중인 위임 작업이 없습니다."
    }

    private static func buildSchedulePolicyResponse() -> String {
        var output = "# 로컬 스케줄 정책\n\n"

        output += "## 읽기/보기 명령\n"
        output += "- \"스케줄 열어줘\" — 스케줄 패널 열기\n"
        output += "- \"오늘 스케줄 보여줘\" — 오늘 예정된 업무 목록\n"
        output += "- \"승인 대기 보여줘\" — 승인을 기다리는 작업 목록\n"
        output += "- \"오늘 업무 뭐 남았어\" — 오늘 남은 업무 요약\n"
        output += "- \"오늘 스케줄 기준으로 할 일 정리해줘\" — 시간순 정렬 업무 계획\n"
        output += "- \"진행 중인 위임 작업 보여줘\" — 위임된 작업 상태\n\n"

        output += "## 금지된 명령\n"
        output += "- 일정 자동 생성 (\"일정 만들어줘\")\n"
        output += "- 외부 캘린더 연동 쓰기 (\"캘린더에 추가해줘\")\n"
        output += "- 자동 승인 (수동 검토 필요)\n"
        output += "- 자동 실행 (사용자 승인 필요)\n"

        return output
    }

    private static func getTodayTasks(roomID: UUID, manager: AgentWindowManager) -> [AgentWindowManager.AutomationTask] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        return manager.automationTasks.filter { task in
            // Room-specific task has priority
            if let taskRoomID = task.roomID, taskRoomID != roomID {
                return false
            }

            // Task must be scheduled for today
            return task.nextRunAt >= today && task.nextRunAt < tomorrow
        }
    }

    private static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private static func getAgentName(_ agentID: String?, manager: AgentWindowManager) -> String {
        guard let agentID = agentID else { return "시스템" }
        // Agent name lookup: for now, return the agentID or known names
        let knownNames: [String: String] = [
            "raki": "래키",
            "luna": "루나",
            "mika": "미카",
            "system": "시스템"
        ]
        return knownNames[agentID.lowercased()] ?? agentID
    }
}
