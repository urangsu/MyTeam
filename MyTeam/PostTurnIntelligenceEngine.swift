import Foundation

actor PostTurnIntelligenceEngine {
    static let shared = PostTurnIntelligenceEngine()

    @MainActor
    func suggestNextActions(
        roomID: UUID,
        latestUserText: String,
        assistantText: String,
        chainRun: ChainRun?,
        connectorHealth: ConnectorHealth
    ) async -> [ActionSuggestion] {
        if let chainRun, !chainRun.actions.isEmpty {
            return chainRun.actions
        }

        let combined = (latestUserText + " " + assistantText).lowercased()

        if combined.contains("메일") || combined.contains("email") || combined.contains("gmail") {
            return await MainActor.run {
                [
                    ActionSuggestion(type: "reply_draft", title: "답장 초안 만들기", preview: "메일 내용을 바탕으로 답장 초안을 만듭니다.", handlerID: .replyDraft),
                    ActionSuggestion(type: "todo_card", title: "할 일 카드로 저장", preview: "메일에서 해야 할 일을 분리해 저장합니다.", handlerID: .todoCreate),
                    ActionSuggestion(type: "calendar_draft", title: "캘린더 초안 만들기", preview: "일정 후보를 초안으로 정리합니다.", requiresApproval: true, handlerID: .calendarDraft)
                ]
            }
        }

        if combined.contains("pdf") || combined.contains("문서") || combined.contains("공문") || combined.contains("회의록") {
            return await MainActor.run {
                [
                    ActionSuggestion(type: "document_artifact", title: "요약 문서 저장", preview: "문서 내용을 카드와 문서로 같이 남깁니다.", handlerID: .createDocument),
                    ActionSuggestion(type: "deadline_extract", title: "마감 찾기", preview: "기한과 해야 할 일을 다시 뽑습니다.", handlerID: .summarizeArtifact)
                ]
            }
        }

        if combined.contains("주가") || combined.contains("주식") || combined.contains("종목") {
            return await MainActor.run {
                [
                    ActionSuggestion(type: "stock_memo", title: "투자 메모로 저장", preview: "시세와 근거를 방에 메모로 남깁니다.", handlerID: .saveMemo),
                    ActionSuggestion(type: "disclosure_followup", title: "공시 더 확인", preview: "공시와 시장 근거를 더 확인합니다.", handlerID: .summarizeArtifact)
                ]
            }
        }

        if combined.contains("ktx") || combined.contains("srt") || combined.contains("기차") {
            let canDraftCalendar: Bool
            switch connectorHealth.calendarDraft {
            case .approvalRequired:
                canDraftCalendar = true
            default:
                canDraftCalendar = false
            }
            return await MainActor.run {
                [
                    ActionSuggestion(type: "copy_search_conditions", title: "검색 조건 복사", preview: "이동 조건을 바로 붙여넣을 수 있게 정리합니다.", handlerID: .openBooking),
                    ActionSuggestion(type: "calendar_draft", title: "일정 초안 만들기", preview: "이동 후보를 일정 초안으로 옮깁니다.", requiresApproval: canDraftCalendar, handlerID: .calendarDraft)
                ]
            }
        }

        return await MainActor.run {
            [
                ActionSuggestion(type: "save_card", title: "카드 저장", preview: "이 답변을 방 안 결과 카드로 남깁니다.", handlerID: .saveMemo)
            ]
        }
    }
}
