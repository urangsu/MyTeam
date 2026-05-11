import Foundation

enum LocalSchedulerCommandDetector {
    static func detect(_ message: String) -> LocalSchedulerCommand? {
        let normalized = message.lowercased().trimmingCharacters(in: .whitespaces)

        // 스케줄 열기
        if normalized.contains("스케줄 열어줘") || normalized.contains("일정 열어줘") {
            return LocalSchedulerCommand(
                kind: .openSchedulePanel,
                sourceMessage: message
            )
        }

        // 오늘 스케줄 보기
        if (normalized.contains("오늘 스케줄") || normalized.contains("오늘 일정")) &&
            (normalized.contains("보여") || normalized.contains("알려") || normalized.contains("뭐")) &&
            !normalized.contains("메일") &&
            !normalized.contains("카테고리") {
            return LocalSchedulerCommand(
                kind: .showTodaySchedule,
                sourceMessage: message
            )
        }

        // 오늘 앱 스케줄 (일정과 구분)
        if normalized.contains("오늘") && normalized.contains("앱 스케줄") {
            return LocalSchedulerCommand(
                kind: .showTodaySchedule,
                sourceMessage: message
            )
        }

        // 승인 대기 보기
        if (normalized.contains("승인 대기") || normalized.contains("승인 필요")) &&
            (normalized.contains("보여") || normalized.contains("뭐") || normalized.contains("있어")) {
            return LocalSchedulerCommand(
                kind: .showPendingApprovals,
                sourceMessage: message
            )
        }

        // 오늘 업무 남은 것
        if normalized.contains("오늘 업무") &&
            (normalized.contains("뭐 남았어") || normalized.contains("남은") || normalized.contains("남은 거")) {
            return LocalSchedulerCommand(
                kind: .summarizeRemainingWork,
                sourceMessage: message
            )
        }

        // 오늘 할 일 정리
        if normalized.contains("오늘 스케줄") &&
            (normalized.contains("할 일") || normalized.contains("업무")) &&
            normalized.contains("정리") {
            return LocalSchedulerCommand(
                kind: .summarizeScheduleBasedTasks,
                sourceMessage: message
            )
        }

        // 진행 중인 위임 작업
        if (normalized.contains("위임") || normalized.contains("위임 작업")) &&
            (normalized.contains("보여") || normalized.contains("뭐") || normalized.contains("진행")) {
            return LocalSchedulerCommand(
                kind: .showDelegatedWork,
                sourceMessage: message
            )
        }

        // 스케줄 정책
        if normalized.contains("스케줄 정책") {
            return LocalSchedulerCommand(
                kind: .showSchedulePolicy,
                sourceMessage: message
            )
        }

        return nil
    }
}
