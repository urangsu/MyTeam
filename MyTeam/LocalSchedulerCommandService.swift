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
            return buildTodayScheduleResponse()

        case .showPendingApprovals:
            return buildPendingApprovalsResponse(manager: manager)

        case .summarizeRemainingWork:
            return buildRemainingWorkSummary()

        case .summarizeScheduleBasedTasks:
            return buildScheduleBasedTasksSummary()

        case .showDelegatedWork:
            return buildDelegatedWorkResponse()

        case .showSchedulePolicy:
            return buildSchedulePolicyResponse()
        }
    }

    private static func buildTodayScheduleResponse() -> String {
        return """
        # 오늘 로컬 스케줄

        ## 예정된 작업
        (등록된 스케줄 업무가 없습니다.)

        ## 다음 액션
        - 스케줄 앱이나 자동화 패널에서 업무를 추가할 수 있습니다.
        """
    }

    private static func buildPendingApprovalsResponse(manager: AgentWindowManager) -> String {
        let pendingCount = manager.pendingApprovalTaskIDs.count

        guard pendingCount > 0 else {
            return "현재 승인 대기 작업이 없습니다."
        }

        return """
        # 승인 대기

        총 \(pendingCount)건의 작업이 승인을 기다리고 있습니다.

        ## 다음 액션
        - 각 작업을 확인 후 승인하거나 거절할 수 있습니다.
        """
    }

    private static func buildRemainingWorkSummary() -> String {
        return """
        # 오늘 남은 업무

        로컬 스케줄 정보를 불러올 수 없습니다.

        ## 다음 액션
        - 스케줄 패널을 열어 직접 확인할 수 있습니다.
        """
    }

    private static func buildScheduleBasedTasksSummary() -> String {
        return """
        # 오늘 스케줄 기준 할 일

        로컬 스케줄 정보를 불러올 수 없습니다.

        ## 다음 액션
        - 스케줄 패널을 열어 시간순 업무를 확인할 수 있습니다.
        """
    }

    private static func buildDelegatedWorkResponse() -> String {
        return """
        # 진행 중인 위임 작업

        현재 진행 중인 위임 작업이 없습니다.
        """
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
}
