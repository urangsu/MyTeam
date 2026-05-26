import Foundation

enum ChainOrchestrator {
    @MainActor
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

    @MainActor
    private static func buildSteps(
        chainID: SkillChainID,
        userMessage: String,
        attachments: [ChatAttachment],
        evidence: ToolEvidenceResult,
        health: ConnectorHealth
    ) -> [ChainStep] {
        switch chainID {
        case .stockMoveAnalysis:
            let hasQuote = evidence.sources.contains(where: isQuoteSource)
            let hasNews = evidence.sources.contains(where: isNewsSource)
            let hasDisclosure = evidence.sources.contains(where: isDisclosureSource)
            return [
                ChainStep(
                    key: "normalizeTicker",
                    title: "종목/질문 정규화",
                    detail: normalizedStockHint(from: userMessage),
                    status: .succeeded
                ),
                ChainStep(
                    key: "fetchQuote",
                    title: "시세 조회",
                    detail: health.stockQuote.label,
                    status: health.stockQuote == .available
                        ? (hasQuote ? .succeeded : .failed(failureCode: "quote_unverified"))
                        : .failed(failureCode: "quote_connector_unavailable")
                ),
                ChainStep(
                    key: "fetchMarketIndex",
                    title: "시장 맥락 조회",
                    detail: health.webFetch.label,
                    status: health.webFetch == .available
                        ? ((hasNews || hasDisclosure || !evidence.promptContext.isEmpty) ? .succeeded : .skipped(reason: "시장 맥락을 뒷받침할 자료가 아직 없어요"))
                        : .skipped(reason: health.webFetch.reason ?? "웹 조회 불가")
                ),
                ChainStep(
                    key: "searchNews",
                    title: "관련 뉴스 검색",
                    detail: health.newsSearch.label,
                    status: health.newsSearch == .available
                        ? (hasNews ? .succeeded : .skipped(reason: "뉴스 근거가 아직 없어요"))
                        : .failed(failureCode: "news_connector_unavailable")
                ),
                ChainStep(
                    key: "searchDisclosure",
                    title: "공시 검색",
                    detail: health.disclosureSearch.label,
                    status: health.disclosureSearch == .available
                        ? (hasDisclosure ? .succeeded : .skipped(reason: "공시 근거가 아직 없어요"))
                        : .failed(failureCode: "disclosure_connector_unavailable")
                ),
                ChainStep(
                    key: "analyzeCause",
                    title: "원인 후보 분석",
                    status: hasQuote && (hasNews || hasDisclosure)
                        ? .succeeded
                        : .skipped(reason: "시세와 외부 근거를 함께 확인해야 해요")
                ),
                ChainStep(
                    key: "verifySources",
                    title: "근거 검증",
                    status: hasQuote && (hasNews || hasDisclosure) && evidence.sources.count >= 2
                        ? .succeeded
                        : .failed(failureCode: "insufficient_sources")
                ),
                ChainStep(
                    key: "renderStockMoveCard",
                    title: "원인 카드 생성",
                    status: hasQuote && (hasNews || hasDisclosure) && evidence.sources.count >= 2
                        ? .succeeded
                        : .skipped(reason: "검증이 아직 부족해요")
                )
            ]

        case .mailAction:
            let hasAttachment = !attachments.isEmpty
            let hasTextAttachment = attachments.contains { hasUsableAttachmentText($0) }
            let attachmentNames = attachments.map(\.fileName).joined(separator: ", ")
            let mailText = mailBody(from: userMessage, attachments: attachments)
            let hasScheduleHint = containsScheduleHint(in: mailText)
            return [
                ChainStep(
                    key: "readMailSource",
                    title: "메일 원문 읽기",
                    detail: attachmentNames.isEmpty ? nil : attachmentNames,
                    status: hasAttachment ? .succeeded : .skipped(reason: "메일 본문 또는 첨부가 필요합니다")
                ),
                ChainStep(
                    key: "summarizeMail",
                    title: "메일 요약",
                    status: hasTextAttachment || !userMessage.isEmpty ? .succeeded : .skipped(reason: "요약할 원문이 없어요")
                ),
                ChainStep(
                    key: "extractActionItems",
                    title: "해야 할 일 추출",
                    status: hasTextAttachment ? .succeeded : .skipped(reason: "액션 아이템이 없어요")
                ),
                ChainStep(
                    key: "extractDateTime",
                    title: "날짜/시간 추출",
                    status: hasScheduleHint ? .succeeded : .skipped(reason: "일정 정보가 없어요")
                ),
                ChainStep(
                    key: "createReplyDraft",
                    title: "답장 초안",
                    status: hasTextAttachment || !userMessage.isEmpty ? .succeeded : .skipped(reason: "답장 초안 근거가 부족해요")
                ),
                ChainStep(
                    key: "createCalendarDraftSuggestion",
                    title: "캘린더 초안 제안",
                    status: hasScheduleHint ? .succeeded : .skipped(reason: "캘린더 초안 근거가 부족해요")
                ),
                ChainStep(
                    key: "createTodoSuggestion",
                    title: "할 일 제안",
                    status: hasTextAttachment ? .succeeded : .skipped(reason: "할 일 추출 근거가 부족해요")
                )
            ]

        case .documentAction:
            let hasAttachment = !attachments.isEmpty
            let hasTextAttachment = attachments.contains { hasUsableAttachmentText($0) }
            let attachmentNames = attachments.map(\.fileName).joined(separator: ", ")
            return [
                ChainStep(
                    key: "extractText",
                    title: "텍스트 추출",
                    detail: attachmentNames.isEmpty ? nil : attachmentNames,
                    status: hasTextAttachment ? .succeeded : (hasAttachment ? .skipped(reason: "OCR 또는 텍스트 추출이 필요합니다") : .skipped(reason: "첨부가 없습니다"))
                ),
                ChainStep(
                    key: "classifyDocument",
                    title: "문서 유형 분류",
                    status: hasAttachment ? .succeeded : .skipped(reason: "문서가 없습니다")
                ),
                ChainStep(
                    key: "extractDates",
                    title: "날짜 추출",
                    status: hasTextAttachment ? .succeeded : .skipped(reason: "날짜가 없습니다")
                ),
                ChainStep(
                    key: "extractAmounts",
                    title: "금액 추출",
                    status: hasTextAttachment ? .succeeded : .skipped(reason: "금액이 없습니다")
                ),
                ChainStep(
                    key: "extractRisks",
                    title: "리스크 추출",
                    status: hasTextAttachment ? .succeeded : .skipped(reason: "리스크 근거가 없습니다")
                ),
                ChainStep(
                    key: "createChecklist",
                    title: "체크리스트 생성",
                    status: hasTextAttachment ? .succeeded : .skipped(reason: "체크리스트를 만들 원문이 없습니다")
                ),
                ChainStep(
                    key: "createSummaryArtifact",
                    title: "요약 artifact 생성",
                    status: hasTextAttachment ? .succeeded : .skipped(reason: "요약 artifact를 만들 원문이 없습니다")
                )
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

    @MainActor
    private static func normalizedStockHint(from message: String) -> String? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(64))
    }

    @MainActor
    private static func hasUsableAttachmentText(_ attachment: ChatAttachment) -> Bool {
        guard let text = attachment.textContent?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !text.isEmpty
    }

    @MainActor
    private static func mailBody(from userMessage: String, attachments: [ChatAttachment]) -> String {
        let attachmentText = attachments.compactMap { $0.textContent }
            .joined(separator: "\n")
        return [userMessage, attachmentText]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
    }

    @MainActor
    private static func containsScheduleHint(in text: String) -> Bool {
        let lower = text.lowercased()
        let keywords = [
            "내일", "오늘", "모레", "오전", "오후", "시 ", "시,", "시.", "분", "일정", "회의",
            "약속", "미팅", "마감", "due", "meeting", "schedule", "appointment", "calendar"
        ]
        if keywords.contains(where: { lower.contains($0.lowercased()) }) {
            return true
        }
        return text.range(of: #"\b\d{1,2}:\d{2}\b"#, options: .regularExpression) != nil
            || text.range(of: #"\b\d{1,2}월\s*\d{1,2}일\b"#, options: .regularExpression) != nil
            || text.range(of: #"\b\d{1,2}/\d{1,2}\b"#, options: .regularExpression) != nil
    }

    @MainActor
    private static func isQuoteSource(_ source: AgentWindowManager.SourceReference) -> Bool {
        let provider = source.provider.lowercased()
        let title = source.title.lowercased()
        return provider.contains("naver")
            || provider.contains("yahoo")
            || provider.contains("finance")
            || title.contains("주가")
            || title.contains("quote")
    }

    @MainActor
    private static func isNewsSource(_ source: AgentWindowManager.SourceReference) -> Bool {
        let provider = source.provider.lowercased()
        let title = source.title.lowercased()
        return provider.contains("news") || title.contains("뉴스") || title.contains("기사")
    }

    @MainActor
    private static func isDisclosureSource(_ source: AgentWindowManager.SourceReference) -> Bool {
        let provider = source.provider.lowercased()
        let title = source.title.lowercased()
        return provider.contains("dart") || title.contains("공시") || title.contains("사업보고서")
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
