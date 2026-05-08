import Foundation

enum TeamCollaborationStatusProvider {
    static func currentStatus(
        isWorkflowRunning: Bool,
        latestEventSummary: String?,
        idleIndex: Int,
        currentTask: String? = nil,
        activeAgentNames: [String] = []
    ) -> TeamCollaborationStatus {
        let normalizedTask = (currentTask ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSummary = latestEventSummary?.lowercased() ?? ""

        if isWorkflowRunning {
            if normalizedSummary.contains("workflowcompleted") {
                return TeamCollaborationStatus(
                    kind: .completed,
                    title: "작업 완료",
                    detail: normalizedTask.isEmpty ? "결과를 정리하는 중입니다." : normalizedTask,
                    agentName: nil
                )
            }

            if normalizedSummary.contains("workflowcancelled") || normalizedSummary.contains("modelcallfailed") || normalizedSummary.contains("validationfailed") {
                return TeamCollaborationStatus(
                    kind: .failed,
                    title: "확인 필요",
                    detail: normalizedTask.isEmpty ? "작업이 멈췄습니다." : normalizedTask,
                    agentName: nil
                )
            }

            if normalizedSummary.contains("artifactcreated") || taskMentionsArtifact(normalizedTask) {
                return TeamCollaborationStatus(
                    kind: .generatingArtifact,
                    title: artifactTitle(for: normalizedTask),
                    detail: normalizedTask.isEmpty ? "산출물을 정리하는 중입니다." : normalizedTask,
                    agentName: nil
                )
            }

            if normalizedSummary.contains("toolcallstarted") || normalizedSummary.contains("modelcallstarted") {
                return TeamCollaborationStatus(
                    kind: taskMentionsResearch(normalizedTask) ? .gathering : .thinking,
                    title: workingTitle(for: normalizedTask, fallback: "검토 중"),
                    detail: normalizedTask.isEmpty ? "현재 작업을 처리 중입니다." : normalizedTask,
                    agentName: nil
                )
            }

            if normalizedSummary.contains("routedecided") || normalizedSummary.contains("workflowstarted") {
                return TeamCollaborationStatus(
                    kind: .planning,
                    title: workingTitle(for: normalizedTask, fallback: "계획 수립 중"),
                    detail: normalizedTask.isEmpty ? "작업 방향을 정리하는 중입니다." : normalizedTask,
                    agentName: nil
                )
            }

            return TeamCollaborationStatus(
                kind: .waitingForUser,
                title: workingTitle(for: normalizedTask, fallback: "사용자 확인 대기 중"),
                detail: normalizedTask.isEmpty ? "팀이 다음 입력을 기다리고 있습니다." : normalizedTask,
                agentName: nil
            )
        }

        let agentName = pickIdleAgentName(activeAgentNames: activeAgentNames, idleIndex: idleIndex)
        let idleLine = idleLine(for: agentName, index: idleIndex)
        return TeamCollaborationStatus(
            kind: .idle,
            title: idleLine,
            detail: "대기중",
            agentName: agentName
        )
    }

    private static func workingTitle(for task: String, fallback: String) -> String {
        let lowered = task.lowercased()
        if lowered.contains("ppt") || lowered.contains("슬라이드") || lowered.contains("발표") {
            return "PPT 구성 중"
        }
        if lowered.contains("엑셀") || lowered.contains("스프레드시트") || lowered.contains("표 ") || lowered.contains("표정리") {
            return "엑셀 구조 정리 중"
        }
        if lowered.contains("문서") || lowered.contains("약관") || lowered.contains("privacy") || lowered.contains("terms") {
            return "문서 작성 중"
        }
        if lowered.contains("자료") || lowered.contains("검색") || lowered.contains("리서치") || lowered.contains("조사") {
            return "자료 확인 중"
        }
        if lowered.contains("정리") || lowered.contains("계획") || lowered.contains("전략") {
            return "계획 수립 중"
        }
        if lowered.contains("검토") || lowered.contains("리뷰") || lowered.contains("분석") {
            return "검토 중"
        }
        return fallback
    }

    private static func artifactTitle(for task: String) -> String {
        let lowered = task.lowercased()
        if lowered.contains("ppt") || lowered.contains("슬라이드") {
            return "PPT 구성 중"
        }
        if lowered.contains("엑셀") || lowered.contains("스프레드시트") {
            return "엑셀 구조 정리 중"
        }
        return "결과 정리 중"
    }

    private static func taskMentionsArtifact(_ task: String) -> Bool {
        let lowered = task.lowercased()
        return lowered.contains("ppt") || lowered.contains("슬라이드") || lowered.contains("엑셀") || lowered.contains("표")
    }

    private static func taskMentionsResearch(_ task: String) -> Bool {
        let lowered = task.lowercased()
        return lowered.contains("자료") || lowered.contains("검색") || lowered.contains("리서치") || lowered.contains("조사")
    }

    private static func pickIdleAgentName(activeAgentNames: [String], idleIndex: Int) -> String? {
        guard !activeAgentNames.isEmpty else { return nil }
        let safeIndex = abs(idleIndex) % activeAgentNames.count
        return activeAgentNames[safeIndex]
    }

    private static func idleLine(for agentName: String?, index: Int) -> String {
        let genericLines = [
            "대기중",
            "치코가 픽셀 하나를 30분째 고민 중",
            "렉스가 리스크를 노려보는 중",
            "핀은 색상 간격을 맞추는 중",
            "모코가 다음 할 일을 정리하는 중",
            "루나가 문장 톤을 고르는 중",
            "레오가 우선순위를 다듬는 중",
            "래키가 세부 조건을 체크하는 중",
            "폴라가 결과를 조용히 정리하는 중",
            "올리버가 흐름을 맞추는 중",
            "몽몽이 마감선을 확인하는 중",
            "케이가 구조를 다듬는 중"
        ]

        if let agentName {
            switch agentName.lowercased() {
            case "치코": return "치코가 픽셀 하나를 30분째 고민 중"
            case "렉스": return "렉스가 리스크를 노려보는 중"
            case "핀": return "핀은 색상 간격을 맞추는 중"
            case "모코": return "모코가 다음 할 일을 정리하는 중"
            case "루나": return "루나가 문장 톤을 고르는 중"
            case "레오": return "레오가 우선순위를 다듬는 중"
            case "래키": return "래키가 세부 조건을 체크하는 중"
            case "폴라": return "폴라가 결과를 조용히 정리하는 중"
            case "올리버": return "올리버가 흐름을 맞추는 중"
            case "몽몽": return "몽몽이 마감선을 확인하는 중"
            case "케이": return "케이가 구조를 다듬는 중"
            default: break
            }
        }

        return genericLines[abs(index) % genericLines.count]
    }
}
