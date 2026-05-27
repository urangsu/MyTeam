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
        guard let chainRun else {
            return [
                ActionSuggestion(type: "save_card", title: "카드 저장", preview: "이 답변을 방 안 결과 카드로 남깁니다.", handlerID: .saveMemo)
            ]
        }

        switch chainRun.chainID {
        case .mailAction:
            return actionsForMail(chainRun)
        case .documentAction:
            return actionsForDocument(chainRun)
        case .stockMoveAnalysis:
            return actionsForStock(chainRun, connectorHealth: connectorHealth)
        case .tripPlanning:
            return actionsForTrip(chainRun, connectorHealth: connectorHealth)
        case .accountReview:
            return actionsForAccount(chainRun)
        case .research:
            return actionsForResearch(chainRun)
        }
    }

    @MainActor
    private func actionsForMail(_ run: ChainRun) -> [ActionSuggestion] {
        guard stepSucceeded("readMailSource", in: run) else {
            if stepFailed("mail_body_ambiguous", in: run) {
                return [
                    ActionSuggestion(type: "mail_as_body", title: "메일 본문으로 처리", preview: "짧은 문장을 메일 원문으로 보고 다시 요약합니다."),
                    ActionSuggestion(type: "paste_mail_body", title: "메일 본문 붙여넣기", preview: "메일 원문을 붙여넣으면 요약과 할 일 추출을 이어갑니다."),
                    ActionSuggestion(type: "attach_mail_capture", title: "캡처/파일 올리기", preview: "메일 캡처나 eml/txt 파일을 올려 분석합니다.")
                ]
            }
            return [
                ActionSuggestion(type: "paste_mail_body", title: "메일 본문 붙여넣기", preview: "메일 원문을 붙여넣으면 요약과 할 일 추출을 이어갑니다."),
                ActionSuggestion(type: "attach_mail_capture", title: "캡처/파일 올리기", preview: "메일 캡처나 eml/txt 파일을 올려 분석합니다.")
            ]
        }

        var actions = [
            ActionSuggestion(type: "reply_draft", title: "답장 초안을 문서로 저장", preview: "메일 내용을 바탕으로 답장 초안을 이 방의 문서 artifact로 저장합니다.", handlerID: .replyDraft),
            ActionSuggestion(type: "todo_card", title: "할 일을 카드로 저장", preview: "메일에서 해야 할 일을 분리해 저장합니다.", handlerID: .todoCreate)
        ]
        if stepSucceeded("extractDateTime", in: run) {
            actions.append(
                ActionSuggestion(type: "calendar_draft", title: "캘린더 초안 카드 만들기", preview: "일정 후보를 방 안의 카드로 정리합니다.", requiresApproval: true, handlerID: .calendarDraft)
            )
        }
        return actions
    }

    @MainActor
    private func actionsForDocument(_ run: ChainRun) -> [ActionSuggestion] {
        guard stepSucceeded("extractText", in: run) else {
            return [
                ActionSuggestion(type: "ocr_required", title: "OCR/텍스트 추출 필요", preview: "이미지나 스캔 PDF에서 텍스트를 먼저 추출해야 요약할 수 있습니다."),
                ActionSuggestion(type: "attach_text_file", title: "텍스트 있는 파일 올리기", preview: "텍스트 추출 가능한 PDF, txt, docx를 올리면 이어서 처리합니다.")
            ]
        }
        return [
            ActionSuggestion(type: "document_artifact", title: "요약 문서 저장", preview: "문서 내용을 카드와 문서로 같이 남깁니다.", handlerID: .createDocument),
            ActionSuggestion(type: "deadline_extract", title: "마감·담당자 추출", preview: "기한과 해야 할 일을 다시 뽑습니다.", handlerID: .summarizeArtifact)
        ]
    }

    @MainActor
    private func actionsForStock(_ run: ChainRun, connectorHealth: ConnectorHealth) -> [ActionSuggestion] {
        let hasQuote = stepSucceeded("fetchQuote", in: run)
        let hasNarrative = stepSucceeded("searchNews", in: run) || stepSucceeded("searchDisclosure", in: run)
        guard hasQuote else {
            return [
                ActionSuggestion(type: "setup_quote_connector", title: "시세 출처 확인", preview: connectorHealth.stockQuote.reason ?? "시세 조회 커넥터 설정이 필요합니다."),
                ActionSuggestion(type: "check_news_source", title: "뉴스/공시 자료 붙여넣기", preview: "기사나 공시 링크를 주면 원인 후보를 분리합니다.")
            ]
        }
        guard hasNarrative else {
            return [
                ActionSuggestion(type: "check_news_source", title: "뉴스/공시 더 확인", preview: "시세는 확인했지만 원인 근거가 부족합니다.", handlerID: .summarizeArtifact)
            ]
        }
        return [
            ActionSuggestion(type: "stock_memo", title: "투자 메모로 저장", preview: "시세와 근거를 방에 메모로 남깁니다.", handlerID: .saveMemo),
            ActionSuggestion(type: "disclosure_followup", title: "공시 더 확인", preview: "공시와 시장 근거를 더 확인합니다.", handlerID: .summarizeArtifact)
        ]
    }

    @MainActor
    private func actionsForTrip(_ run: ChainRun, connectorHealth: ConnectorHealth) -> [ActionSuggestion] {
        var actions = [
            ActionSuggestion(type: "copy_search_conditions", title: "검색 조건 복사", preview: "예매를 완료한 것이 아니라, 검색 조건만 준비합니다.", handlerID: .openBooking)
        ]
        if stepSucceeded("composeItinerary", in: run) || connectorHealth.calendarDraft == .approvalRequired {
            actions.append(
                ActionSuggestion(type: "calendar_draft", title: "일정 초안 카드 만들기", preview: "이동 후보를 방 안의 일정 카드로 옮깁니다.", requiresApproval: true, handlerID: .calendarDraft)
            )
        }
        return actions
    }

    @MainActor
    private func actionsForAccount(_ run: ChainRun) -> [ActionSuggestion] {
        guard stepSucceeded("readLedger", in: run) else {
            return [
                ActionSuggestion(type: "attach_ledger", title: "거래내역 파일 올리기", preview: "CSV/XLSX/영수증 텍스트가 있어야 정산 카드를 만들 수 있습니다.")
            ]
        }
        return [
            ActionSuggestion(type: "settlement_table", title: "정산표 카드 만들기", preview: "거래내역을 금액·일자·증빙 상태로 정리합니다.", handlerID: .createDocument),
            ActionSuggestion(type: "evidence_mail", title: "증빙 요청 메일 초안을 문서로 저장", preview: "누락 증빙을 요청하는 메일 초안을 이 방의 문서 artifact로 저장합니다.", handlerID: .replyDraft)
        ]
    }

    @MainActor
    private func actionsForResearch(_ run: ChainRun) -> [ActionSuggestion] {
        guard stepSucceeded("gatherSources", in: run) else {
            return [
                ActionSuggestion(type: "provide_source", title: "출처 링크 붙여넣기", preview: "공개 출처를 찾지 못했어요. 링크나 본문을 주면 비교해드립니다.")
            ]
        }
        return [
            ActionSuggestion(type: "save_card", title: "카드 저장", preview: "확인한 내용을 방 안에 결과 카드로 남깁니다.", handlerID: .saveMemo)
        ]
    }

    @MainActor
    private func stepSucceeded(_ key: String, in run: ChainRun) -> Bool {
        run.steps.contains { $0.key == key && $0.status == .succeeded }
    }

    @MainActor
    private func stepFailed(_ failureCode: String, in run: ChainRun) -> Bool {
        run.steps.contains { step in
            if case .failed(let code) = step.status {
                return code == failureCode
            }
            return step.failureDetail == failureCode
        }
    }
}
