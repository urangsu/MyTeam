import Foundation

enum TeamCollaborationStatusProvider {
    static func currentStatus(
        isWorkflowRunning: Bool,
        workflowStatus: WorkflowStatus?,
        teamRuntimeState: TeamRuntimeState?,
        latestEventType: AgentEventType?,
        latestToolName: String?,
        latestEventTimestamp: Date?,
        idleIndex: Int,
        currentTask: String? = nil,
        activeAgentNames: [String] = []
    ) -> TeamCollaborationStatus {
        let normalizedTask = (currentTask ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()
        let isRecent = latestEventTimestamp.map { now.timeIntervalSince($0) <= 25 } ?? false

        if workflowStatus == .failed, isRecent {
            return status(
                kind: .failed,
                title: "확인 필요",
                detail: normalizedTask.isEmpty ? "작업을 다시 확인해 주세요." : normalizedTask,
                timestamp: latestEventTimestamp
            )
        }

        if workflowStatus == .completed, isRecent {
            return status(
                kind: .completed,
                title: "완료",
                detail: normalizedTask.isEmpty ? "파일 생성이 끝났습니다." : normalizedTask,
                timestamp: latestEventTimestamp
            )
        }

        if isWorkflowRunning || workflowStatus == .running {
            if let latestEventType {
                switch latestEventType {
                case .workflowCancelled, .modelCallFailed, .validationFailed:
                    return status(
                        kind: .failed,
                        title: "확인 필요",
                        detail: normalizedTask.isEmpty ? "작업이 멈췄습니다." : normalizedTask,
                        timestamp: latestEventTimestamp
                    )

                case .workflowCompleted:
                    return status(
                        kind: .completed,
                        title: "완료",
                        detail: normalizedTask.isEmpty ? "파일 생성이 끝났습니다." : normalizedTask,
                        timestamp: latestEventTimestamp
                    )

                case .artifactCreated:
                    return status(
                        kind: .generatingArtifact,
                        title: "파일 생성 중",
                        detail: normalizedTask.isEmpty ? "산출물을 저장하는 중입니다." : normalizedTask,
                        timestamp: latestEventTimestamp
                    )

                case .workflowStarted, .routeDecided:
                    return status(
                        kind: .planning,
                        title: "계획 수립 중",
                        detail: normalizedTask.isEmpty ? "작업 방향을 정리하는 중입니다." : normalizedTask,
                        timestamp: latestEventTimestamp
                    )

                case .toolCallStarted, .toolCallFinished:
                    return toolStatus(
                        toolName: latestToolName,
                        normalizedTask: normalizedTask,
                        timestamp: latestEventTimestamp
                    )

                case .modelCallStarted, .modelCallCompleted:
                    return status(
                        kind: taskMentionsResearch(normalizedTask) ? .gathering : .thinking,
                        title: taskMentionsResearch(normalizedTask) ? "자료 확인 중" : "검토 중",
                        detail: normalizedTask.isEmpty ? "현재 작업을 처리 중입니다." : normalizedTask,
                        timestamp: latestEventTimestamp
                    )

                case .userMessageSubmitted:
                    return status(
                        kind: .waitingForUser,
                        title: "사용자 확인 대기 중",
                        detail: normalizedTask.isEmpty ? "입력 내용을 정리하는 중입니다." : normalizedTask,
                        timestamp: latestEventTimestamp
                    )

                default:
                    break
                }
            }

            return status(
                kind: .waitingForUser,
                title: workingTitle(for: normalizedTask, fallback: "사용자 확인 대기 중"),
                detail: normalizedTask.isEmpty ? "팀이 다음 입력을 기다리고 있습니다." : normalizedTask,
                timestamp: latestEventTimestamp
            )
        }

        if let runtimeState = teamRuntimeState, runtimeState.kind != .idle, runtimeState.isRecent {
            return status(from: runtimeState)
        }

        guard isRecent else {
            return idleStatus(idleIndex: idleIndex, activeAgentNames: activeAgentNames)
        }

        if let latestEventType {
            switch latestEventType {
            case .workflowCancelled, .modelCallFailed, .validationFailed:
                return status(
                    kind: .failed,
                    title: "확인 필요",
                    detail: normalizedTask.isEmpty ? "작업이 멈췄습니다." : normalizedTask,
                    timestamp: latestEventTimestamp
                )

            case .workflowCompleted:
                return status(
                    kind: .completed,
                    title: "완료",
                    detail: normalizedTask.isEmpty ? "파일 생성이 끝났습니다." : normalizedTask,
                    timestamp: latestEventTimestamp
                )

            case .artifactCreated:
                return status(
                    kind: .generatingArtifact,
                    title: "파일 생성 중",
                    detail: normalizedTask.isEmpty ? "산출물을 저장하는 중입니다." : normalizedTask,
                    timestamp: latestEventTimestamp
                )

            case .workflowStarted, .routeDecided:
                return status(
                    kind: .planning,
                    title: "계획 수립 중",
                    detail: normalizedTask.isEmpty ? "작업 방향을 정리하는 중입니다." : normalizedTask,
                    timestamp: latestEventTimestamp
                )

            case .teamDiscussionStarted:
                return status(
                    kind: .planning,
                    title: "팀 협업 시작",
                    detail: normalizedTask.isEmpty ? "팀이 의견을 정리하는 중입니다." : normalizedTask,
                    timestamp: latestEventTimestamp
                )

            case .speakerSelectionStarted:
                return status(
                    kind: .planning,
                    title: "다음 담당자 선택 중",
                    detail: normalizedTask.isEmpty ? "말할 사람을 고르는 중입니다." : normalizedTask,
                    timestamp: latestEventTimestamp
                )

            case .speakerSelectionCompleted:
                return status(
                    kind: .thinking,
                    title: "담당자 선택 완료",
                    detail: normalizedTask.isEmpty ? "발언 순서를 정리했습니다." : normalizedTask,
                    timestamp: latestEventTimestamp
                )

            case .agentTurnStarted:
                return status(
                    kind: .thinking,
                    title: "검토 중",
                    detail: normalizedTask.isEmpty ? "에이전트가 답변을 준비하는 중입니다." : normalizedTask,
                    timestamp: latestEventTimestamp
                )

            case .agentTurnCompleted:
                return status(
                    kind: .completed,
                    title: "응답 완료",
                    detail: normalizedTask.isEmpty ? "에이전트 응답이 반영되었습니다." : normalizedTask,
                    timestamp: latestEventTimestamp
                )

            case .teamDiscussionCompleted:
                return status(
                    kind: .completed,
                    title: "팀 협업 완료",
                    detail: normalizedTask.isEmpty ? "논의가 정리되었습니다." : normalizedTask,
                    timestamp: latestEventTimestamp
                )

            case .teamDiscussionFailed:
                return status(
                    kind: .failed,
                    title: "확인 필요",
                    detail: normalizedTask.isEmpty ? "팀 협업 중 문제가 발생했습니다." : normalizedTask,
                    timestamp: latestEventTimestamp
                )

            case .toolCallStarted, .toolCallFinished:
                return toolStatus(
                    toolName: latestToolName,
                    normalizedTask: normalizedTask,
                    timestamp: latestEventTimestamp
                )

            case .modelCallStarted, .modelCallCompleted:
                return status(
                    kind: taskMentionsResearch(normalizedTask) ? .gathering : .thinking,
                    title: taskMentionsResearch(normalizedTask) ? "자료 확인 중" : "검토 중",
                    detail: normalizedTask.isEmpty ? "현재 작업을 처리 중입니다." : normalizedTask,
                    timestamp: latestEventTimestamp
                )

            case .userMessageSubmitted:
                return status(
                    kind: .waitingForUser,
                    title: "사용자 확인 대기 중",
                    detail: normalizedTask.isEmpty ? "입력 내용을 정리하는 중입니다." : normalizedTask,
                    timestamp: latestEventTimestamp
                )
            }
        }

        if workflowStatus == .running || isWorkflowRunning {
            return status(
                kind: .waitingForUser,
                title: workingTitle(for: normalizedTask, fallback: "사용자 확인 대기 중"),
                detail: normalizedTask.isEmpty ? "팀이 다음 입력을 기다리고 있습니다." : normalizedTask,
                timestamp: latestEventTimestamp
            )
        }

        return idleStatus(idleIndex: idleIndex, activeAgentNames: activeAgentNames)
    }

    private static func status(
        kind: TeamCollaborationStatus.Kind,
        title: String,
        detail: String,
        timestamp: Date?
    ) -> TeamCollaborationStatus {
        TeamCollaborationStatus(kind: kind, title: title, detail: detail, agentName: nil, timestamp: timestamp)
    }

    private static func toolStatus(
        toolName: String?,
        normalizedTask: String,
        timestamp: Date?
    ) -> TeamCollaborationStatus {
        let name = (toolName ?? "").lowercased()
        if name.contains("create_presentation_plan") {
            return status(kind: .planning, title: "PPT 구성 중", detail: normalizedTask.isEmpty ? "발표자료 구조를 잡는 중입니다." : normalizedTask, timestamp: timestamp)
        }
        if name.contains("generate_pptx") || name.contains("create_google_slides") {
            return status(kind: .generatingArtifact, title: "PPT 파일 생성 중", detail: normalizedTask.isEmpty ? "슬라이드를 저장하는 중입니다." : normalizedTask, timestamp: timestamp)
        }
        if name.contains("create_spreadsheet_plan") {
            return status(kind: .planning, title: "표 구조 정리 중", detail: normalizedTask.isEmpty ? "스프레드시트 구조를 잡는 중입니다." : normalizedTask, timestamp: timestamp)
        }
        if name.contains("generate_xlsx") || name.contains("create_google_sheets") {
            return status(kind: .generatingArtifact, title: "엑셀 파일 생성 중", detail: normalizedTask.isEmpty ? "스프레드시트를 저장하는 중입니다." : normalizedTask, timestamp: timestamp)
        }
        if name.contains("create_markdown_report") {
            return status(kind: .writing, title: "문서 초안 작성 중", detail: normalizedTask.isEmpty ? "Markdown 문서를 준비하는 중입니다." : normalizedTask, timestamp: timestamp)
        }
        if name.contains("write_text_file") {
            return status(kind: .writing, title: "파일 저장 중", detail: normalizedTask.isEmpty ? "텍스트 파일을 저장하는 중입니다." : normalizedTask, timestamp: timestamp)
        }
        return status(
            kind: .thinking,
            title: workingTitle(for: normalizedTask, fallback: "검토 중"),
            detail: normalizedTask.isEmpty ? "현재 작업을 처리 중입니다." : normalizedTask,
            timestamp: timestamp
        )
    }

    private static func status(from runtimeState: TeamRuntimeState) -> TeamCollaborationStatus {
        let kind: TeamCollaborationStatus.Kind
        switch runtimeState.kind {
        case .idle:
            kind = .idle
        case .discussionStarted:
            kind = .planning
        case .selectingSpeaker:
            kind = .planning
        case .speakerSelected, .fallbackSpeakerSelected:
            kind = .thinking
        case .agentTurnStarted:
            kind = .thinking
        case .agentTurnCompleted:
            kind = .completed
        case .discussionCompleted:
            kind = .completed
        case .discussionFailed:
            kind = .failed
        }
        return TeamCollaborationStatus(
            kind: kind,
            title: runtimeState.title,
            detail: runtimeState.detail,
            agentName: runtimeState.agentName,
            timestamp: runtimeState.timestamp
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

    private static func idleStatus(idleIndex: Int, activeAgentNames: [String]) -> TeamCollaborationStatus {
        let agentName = pickIdleAgentName(activeAgentNames: activeAgentNames, idleIndex: idleIndex)
        let idleLine = idleLine(for: agentName, index: idleIndex)
        return TeamCollaborationStatus(
            kind: .idle,
            title: idleLine,
            detail: "대기중",
            agentName: agentName,
            timestamp: Date()
        )
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
