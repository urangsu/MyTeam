import Foundation

enum ChainOrchestrator {
    static func makeRun(
        roomID: UUID,
        chainID: SkillChainID,
        userMessage: String,
        attachments: [ChatAttachment],
        evidence: ToolEvidenceResult,
        actions: [ActionSuggestion],
        health: ConnectorHealth
    ) async -> ChainRun {
        let steps = buildSteps(
            chainID: chainID,
            userMessage: userMessage,
            attachments: attachments,
            evidence: evidence,
            health: health
        )
        let status = overallStatus(for: steps)
        let run = ChainRun(
            roomID: roomID,
            chainID: chainID,
            steps: steps,
            status: status,
            sources: evidence.sources.map {
                ChainSourceReference(
                    title: $0.title,
                    provider: $0.provider,
                    url: $0.url,
                    accessedAt: $0.accessedAt
                )
            },
            actions: actions,
            artifacts: [],
            startedAt: Date(),
            updatedAt: Date()
        )
        await MainActor.run {
            ChainRunStore.shared.upsert(run)
        }
        return run
    }

    private static func buildSteps(
        chainID: SkillChainID,
        userMessage: String,
        attachments: [ChatAttachment],
        evidence: ToolEvidenceResult,
        health: ConnectorHealth
    ) -> [ChainStep] {
        switch chainID {
        case .stockMoveAnalysis:
            return [
                ChainStep(key: "normalizeTicker", title: "종목/질문 정규화", status: .succeeded),
                ChainStep(
                    key: "fetchQuote",
                    title: "시세 조회",
                    detail: health.stockQuote.label,
                    status: health.stockQuote == .available ? (evidence.sources.isEmpty ? .failed(failureCode: "quote_unverified") : .succeeded) : .failed(failureCode: "quote_connector_unavailable")
                ),
                ChainStep(
                    key: "fetchMarketIndex",
                    title: "시장 맥락 조회",
                    detail: health.webFetch.label,
                    status: health.webFetch == .available ? .succeeded : .skipped(reason: health.webFetch.reason ?? "웹 조회 불가")
                ),
                ChainStep(
                    key: "searchNews",
                    title: "관련 뉴스 검색",
                    detail: health.newsSearch.label,
                    status: health.newsSearch == .available ? (evidence.sources.contains(where: { $0.provider.lowercased().contains("news") }) ? .succeeded : .skipped(reason: "뉴스 근거가 아직 없어요")) : .failed(failureCode: "news_connector_unavailable")
                ),
                ChainStep(
                    key: "searchDisclosure",
                    title: "공시 검색",
                    detail: health.disclosureSearch.label,
                    status: health.disclosureSearch == .available ? (evidence.sources.contains(where: { $0.provider.lowercased().contains("dart") }) ? .succeeded : .skipped(reason: "공시 근거가 아직 없어요")) : .failed(failureCode: "disclosure_connector_unavailable")
                ),
                ChainStep(
                    key: "analyzeCause",
                    title: "원인 후보 분석",
                    status: evidence.sources.count >= 2 ? .succeeded : .skipped(reason: "근거가 더 필요해요")
                ),
                ChainStep(
                    key: "verifySources",
                    title: "근거 검증",
                    status: evidence.sources.count >= 2 ? .succeeded : .failed(failureCode: "insufficient_sources")
                ),
                ChainStep(key: "renderStockMoveCard", title: "원인 카드 생성", status: .succeeded)
            ]

        case .mailAction:
            let hasAttachment = !attachments.isEmpty
            return [
                ChainStep(key: "readMailSource", title: "메일 원문 읽기", status: hasAttachment ? .succeeded : .skipped(reason: "메일 본문 또는 첨부가 필요합니다")),
                ChainStep(key: "summarizeMail", title: "메일 요약", status: hasAttachment || !userMessage.isEmpty ? .succeeded : .skipped(reason: "요약할 원문이 없어요")),
                ChainStep(key: "extractActionItems", title: "해야 할 일 추출", status: hasAttachment || !userMessage.isEmpty ? .succeeded : .skipped(reason: "액션 아이템이 없어요")),
                ChainStep(key: "extractDateTime", title: "날짜/시간 추출", status: hasAttachment || !userMessage.isEmpty ? .succeeded : .skipped(reason: "일정 정보가 없어요")),
                ChainStep(key: "createReplyDraft", title: "답장 초안", status: .succeeded),
                ChainStep(key: "createCalendarDraftSuggestion", title: "캘린더 초안 제안", status: .succeeded),
                ChainStep(key: "createTodoSuggestion", title: "할 일 제안", status: .succeeded)
            ]

        case .documentAction:
            let hasAttachment = !attachments.isEmpty
            return [
                ChainStep(key: "extractText", title: "텍스트 추출", status: hasAttachment ? .succeeded : .skipped(reason: "첨부가 없습니다")),
                ChainStep(key: "classifyDocument", title: "문서 유형 분류", status: hasAttachment ? .succeeded : .skipped(reason: "문서가 없습니다")),
                ChainStep(key: "extractDates", title: "날짜 추출", status: hasAttachment ? .succeeded : .skipped(reason: "날짜가 없습니다")),
                ChainStep(key: "extractAmounts", title: "금액 추출", status: hasAttachment ? .succeeded : .skipped(reason: "금액이 없습니다")),
                ChainStep(key: "extractRisks", title: "리스크 추출", status: hasAttachment ? .succeeded : .skipped(reason: "리스크 근거가 없습니다")),
                ChainStep(key: "createChecklist", title: "체크리스트 생성", status: .succeeded),
                ChainStep(key: "createSummaryArtifact", title: "요약 artifact 생성", status: .succeeded)
            ]

        case .tripPlanning:
            return [
                ChainStep(key: "normalizeRoute", title: "이동 조건 정리", status: .succeeded),
                ChainStep(key: "resolveStations", title: "역 후보 정리", status: health.trainSearch == .available ? .succeeded : .skipped(reason: health.trainSearch.reason ?? "열차 조회 연결이 없습니다")),
                ChainStep(key: "lookupTrain", title: "열차 조회", status: health.trainSearch == .available ? .succeeded : .failed(failureCode: "train_connector_unavailable")),
                ChainStep(key: "lookupMapTravelTime", title: "지도 이동 시간 확인", status: health.mapsSearch == .available ? .succeeded : .skipped(reason: health.mapsSearch.reason ?? "지도 조회 연결이 없습니다")),
                ChainStep(key: "composeItinerary", title: "이동 카드 생성", status: .succeeded)
            ]

        case .accountReview:
            let hasAttachment = !attachments.isEmpty
            return [
                ChainStep(key: "readLedger", title: "거래 자료 읽기", status: hasAttachment ? .succeeded : .skipped(reason: "CSV/XLSX/영수증이 필요합니다")),
                ChainStep(key: "normalizeRows", title: "행 정규화", status: hasAttachment ? .succeeded : .skipped(reason: "정규화할 자료가 없습니다")),
                ChainStep(key: "findAnomalies", title: "이상 후보 찾기", status: hasAttachment ? .succeeded : .skipped(reason: "이상 후보를 찾을 자료가 없습니다")),
                ChainStep(key: "createSettlementCard", title: "정산 카드 생성", status: .succeeded)
            ]

        case .research:
            return [
                ChainStep(key: "normalizeQuestion", title: "질문 정규화", status: .succeeded),
                ChainStep(key: "gatherSources", title: "공개 출처 수집", status: evidence.sources.isEmpty ? .failed(failureCode: "no_public_sources") : .succeeded),
                ChainStep(key: "splitClaims", title: "주장 분리", status: evidence.sources.count >= 1 ? .succeeded : .skipped(reason: "출처가 필요합니다")),
                ChainStep(key: "renderResearchCard", title: "리서치 카드 생성", status: .succeeded)
            ]
        }
    }

    private static func overallStatus(for steps: [ChainStep]) -> ChainStatus {
        if steps.contains(where: { if case .failed = $0.status { return true } else { return false } }) {
            return .failed
        }
        if steps.contains(where: { if case .skipped = $0.status { return true } else { return false } }) {
            return .blocked
        }
        if steps.allSatisfy({ if case .succeeded = $0.status { return true } else { return false } }) {
            return .succeeded
        }
        return .running
    }
}
