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
        let runID = UUID()
        let attachedActions = actions.map { $0.with(chainRunID: runID) }
        let steps = buildSteps(
            chainID: chainID,
            userMessage: userMessage,
            attachments: attachments,
            evidence: evidence,
            health: health
        )
        let status = overallStatus(for: steps)
        let run = ChainRun(
            id: runID,
            roomID: roomID,
            chainID: chainID,
            steps: steps,
            status: status,
            sources: evidence.sources.map {
                ChainSourceReference(
                    title: $0.title,
                    provider: $0.provider,
                    url: $0.url,
                    accessedAt: $0.accessedAt,
                    sourceType: $0.resolvedSourceType
                )
            },
            actions: attachedActions,
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
        let hasAttachment = !attachments.isEmpty
        let hasTextAttachment = attachments.contains(where: Self.hasTextAttachment)
        let mailText = mailBody(from: userMessage, attachments: attachments)
        let inlineMailBody = looksLikeMailBody(userMessage)
        let quoteSources = evidence.sources.filter { $0.resolvedSourceType == .quote }
        let newsSources = evidence.sources.filter { $0.resolvedSourceType == .news }
        let disclosureSources = evidence.sources.filter { $0.resolvedSourceType == .disclosure }
        let marketSources = evidence.sources.filter { isMarketSourceType($0.resolvedSourceType) }
        let concreteSources = evidence.sources.filter { isConcreteSource($0.resolvedSourceType) }
        let allSourceIDs = evidence.sources.map(\.id.uuidString)
        let quoteSourceIDs = quoteSources.map(\.id.uuidString)
        let newsSourceIDs = newsSources.map(\.id.uuidString)
        let disclosureSourceIDs = disclosureSources.map(\.id.uuidString)
        let marketSourceIDs = marketSources.map(\.id.uuidString)
        let textAttachmentIDs = attachments.filter { Self.hasTextAttachment($0) }.map(\.id.uuidString)

        switch chainID {
        case .stockMoveAnalysis:
            return [
                step(
                    key: "normalizeTicker",
                    title: "종목/질문 정규화",
                    detail: normalizedStockHint(from: userMessage),
                    status: .succeeded,
                    outputSummary: normalizedStockHint(from: userMessage),
                    sourceIDs: []
                ),
                step(
                    key: "fetchQuote",
                    title: "시세 조회",
                    connectorID: "finance_quote",
                    detail: health.stockQuote.label,
                    status: health.stockQuote == .available
                        ? (quoteSources.isEmpty ? .failed(failureCode: "quote_unverified") : .succeeded)
                        : .failed(failureCode: "quote_connector_unavailable"),
                    outputSummary: quoteSources.isEmpty ? "시세 미확인" : "\(quoteSources.count)개 quote source",
                    sourceIDs: quoteSourceIDs,
                    failureDetail: health.stockQuote.reason ?? (quoteSources.isEmpty ? "quote source missing" : nil)
                ),
                step(
                    key: "fetchMarketIndex",
                    title: "시장 맥락 조회",
                    connectorID: "web_search",
                    detail: health.webFetch.label,
                    status: health.webFetch == .available
                        ? (!marketSources.isEmpty ? .succeeded : .skipped(reason: "시장 맥락을 뒷받침할 자료가 아직 없어요"))
                        : .skipped(reason: health.webFetch.reason ?? "웹 조회 불가"),
                    outputSummary: marketSources.isEmpty ? "시장 맥락 미확인" : "\(marketSources.count)개 market source",
                    sourceIDs: marketSourceIDs,
                    failureDetail: health.webFetch.reason
                ),
                step(
                    key: "searchNews",
                    title: "관련 뉴스 검색",
                    connectorID: "web_search",
                    detail: health.newsSearch.label,
                    status: health.newsSearch == .available
                        ? (!newsSources.isEmpty ? .succeeded : .skipped(reason: "뉴스 근거가 아직 없어요"))
                        : .failed(failureCode: "news_connector_unavailable"),
                    outputSummary: newsSources.isEmpty ? "뉴스 미확인" : "\(newsSources.count)개 news source",
                    sourceIDs: newsSourceIDs,
                    failureDetail: health.newsSearch.reason
                ),
                step(
                    key: "searchDisclosure",
                    title: "공시 검색",
                    connectorID: "disclosure_search",
                    detail: health.disclosureSearch.label,
                    status: health.disclosureSearch == .available
                        ? (!disclosureSources.isEmpty ? .succeeded : .skipped(reason: "공시 근거가 아직 없어요"))
                        : .failed(failureCode: "disclosure_connector_unavailable"),
                    outputSummary: disclosureSources.isEmpty ? "공시 미확인" : "\(disclosureSources.count)개 disclosure source",
                    sourceIDs: disclosureSourceIDs,
                    failureDetail: health.disclosureSearch.reason
                ),
                step(
                    key: "analyzeCause",
                    title: "원인 후보 분석",
                    status: !quoteSources.isEmpty && (!newsSources.isEmpty || !disclosureSources.isEmpty || !marketSources.isEmpty)
                        ? .succeeded
                        : .skipped(reason: "시세와 외부 근거를 함께 확인해야 해요"),
                    outputSummary: !quoteSources.isEmpty ? "원인 후보 생성 준비됨" : "시세 미확인",
                    sourceIDs: allSourceIDs
                ),
                step(
                    key: "verifySources",
                    title: "근거 검증",
                    status: !quoteSources.isEmpty && (!newsSources.isEmpty || !disclosureSources.isEmpty) && concreteSources.count >= 2
                        ? .succeeded
                        : .failed(failureCode: "insufficient_concrete_sources"),
                    outputSummary: "\(concreteSources.count)개 concrete source",
                    sourceIDs: allSourceIDs,
                    failureDetail: concreteSources.count < 2 ? "sourceCount-only verification blocked" : nil
                ),
                step(
                    key: "renderStockMoveCard",
                    title: "원인 카드 생성",
                    status: !quoteSources.isEmpty && (!newsSources.isEmpty || !disclosureSources.isEmpty) && concreteSources.count >= 2
                        ? .succeeded
                        : .skipped(reason: "검증이 아직 부족해요"),
                    outputSummary: concreteSources.count >= 2 ? "검증 카드 생성" : "검증 대기",
                    sourceIDs: allSourceIDs
                )
            ]

        case .mailAction:
            let hasScheduleHint = containsScheduleHint(in: mailText)
            let hasMailSource = hasTextAttachment || inlineMailBody
            let mailSourceIDs = hasTextAttachment ? textAttachmentIDs : (inlineMailBody ? ["inline-mail-body"] : [])
            return [
                step(
                    key: "readMailSource",
                    title: "메일 원문 읽기",
                    connectorID: "mail_read",
                    detail: hasAttachment ? attachments.map(\.fileName).joined(separator: ", ") : nil,
                    status: hasMailSource
                        ? .succeeded
                        : (hasAttachment ? .skipped(reason: "OCR 또는 본문이 필요합니다") : .skipped(reason: "메일 본문이 없습니다")),
                    outputSummary: hasMailSource ? "메일 원문 인식됨" : "메일 원문 없음",
                    sourceIDs: mailSourceIDs,
                    failureDetail: hasMailSource ? nil : (hasAttachment ? "text attachment missing" : "inline mail body missing")
                ),
                step(
                    key: "summarizeMail",
                    title: "메일 요약",
                    status: hasMailSource ? .succeeded : .skipped(reason: "요약할 원문이 없어요"),
                    outputSummary: hasMailSource ? "요약 준비됨" : "요약 불가",
                    sourceIDs: mailSourceIDs
                ),
                step(
                    key: "extractActionItems",
                    title: "해야 할 일 추출",
                    status: hasMailSource ? .succeeded : .skipped(reason: "액션 아이템이 없어요"),
                    outputSummary: hasMailSource ? "할 일 후보 추출됨" : "할 일 없음",
                    sourceIDs: mailSourceIDs
                ),
                step(
                    key: "extractDateTime",
                    title: "날짜/시간 추출",
                    status: hasScheduleHint ? .succeeded : .skipped(reason: "일정 정보가 없어요"),
                    outputSummary: hasScheduleHint ? "일정 후보 있음" : "일정 정보 없음",
                    sourceIDs: mailSourceIDs
                ),
                step(
                    key: "createReplyDraft",
                    title: "답장 초안",
                    status: hasMailSource ? .succeeded : .skipped(reason: "답장 초안 근거가 부족해요"),
                    outputSummary: hasMailSource ? "답장 초안 생성 준비됨" : "답장 초안 불가",
                    sourceIDs: mailSourceIDs
                ),
                step(
                    key: "createCalendarDraftSuggestion",
                    title: "캘린더 초안 제안",
                    status: hasScheduleHint ? .succeeded : .skipped(reason: "캘린더 초안 근거가 부족해요"),
                    outputSummary: hasScheduleHint ? "캘린더 초안 가능" : "캘린더 초안 불가",
                    sourceIDs: mailSourceIDs
                ),
                step(
                    key: "createTodoSuggestion",
                    title: "할 일 제안",
                    status: hasMailSource ? .succeeded : .skipped(reason: "할 일 추출 근거가 부족해요"),
                    outputSummary: hasMailSource ? "할 일 후보 있음" : "할 일 없음",
                    sourceIDs: mailSourceIDs
                )
            ]

        case .documentAction:
            let documentSourceIDs = textAttachmentIDs
            return [
                step(
                    key: "extractText",
                    title: "텍스트 추출",
                    connectorID: "pdf_text",
                    detail: hasAttachment ? attachments.map(\.fileName).joined(separator: ", ") : nil,
                    status: hasTextAttachment
                        ? .succeeded
                        : (hasAttachment ? .skipped(reason: "OCR 또는 텍스트 추출이 필요합니다") : .skipped(reason: "첨부가 없습니다")),
                    outputSummary: hasTextAttachment ? "\(textAttachmentIDs.count)개 text attachment" : (hasAttachment ? "OCR 필요" : "첨부 없음"),
                    sourceIDs: documentSourceIDs,
                    failureDetail: hasTextAttachment ? nil : (hasAttachment ? "ocr_needed" : "no_attachment")
                ),
                step(
                    key: "classifyDocument",
                    title: "문서 유형 분류",
                    status: hasTextAttachment ? .succeeded : .skipped(reason: hasAttachment ? "문서 유형 확정 불가" : "문서가 없습니다"),
                    outputSummary: hasTextAttachment ? "문서 유형 후보 확인" : "분류 대기",
                    sourceIDs: documentSourceIDs
                ),
                step(
                    key: "extractDates",
                    title: "날짜 추출",
                    status: hasTextAttachment ? .succeeded : .skipped(reason: "날짜가 없습니다"),
                    outputSummary: hasTextAttachment ? "날짜 후보 있음" : "날짜 없음",
                    sourceIDs: documentSourceIDs
                ),
                step(
                    key: "extractAmounts",
                    title: "금액 추출",
                    status: hasTextAttachment ? .succeeded : .skipped(reason: "금액이 없습니다"),
                    outputSummary: hasTextAttachment ? "금액 후보 있음" : "금액 없음",
                    sourceIDs: documentSourceIDs
                ),
                step(
                    key: "extractRisks",
                    title: "리스크 추출",
                    status: hasTextAttachment ? .succeeded : .skipped(reason: "리스크 근거가 없습니다"),
                    outputSummary: hasTextAttachment ? "리스크 후보 있음" : "리스크 없음",
                    sourceIDs: documentSourceIDs
                ),
                step(
                    key: "createChecklist",
                    title: "체크리스트 생성",
                    status: hasTextAttachment ? .succeeded : .skipped(reason: "체크리스트를 만들 원문이 없습니다"),
                    outputSummary: hasTextAttachment ? "체크리스트 준비됨" : "체크리스트 불가",
                    sourceIDs: documentSourceIDs
                ),
                step(
                    key: "createSummaryArtifact",
                    title: "요약 artifact 생성",
                    status: hasTextAttachment ? .succeeded : .skipped(reason: "요약 artifact를 만들 원문이 없습니다"),
                    outputSummary: hasTextAttachment ? "요약 artifact 준비됨" : "요약 artifact 불가",
                    sourceIDs: documentSourceIDs
                )
            ]

        case .tripPlanning:
            return [
                step(key: "normalizeRoute", title: "이동 조건 정리", status: .succeeded, outputSummary: "이동 조건 정리됨"),
                step(key: "resolveStations", title: "역 후보 정리", connectorID: "train_search", status: health.trainSearch == .available ? .succeeded : .skipped(reason: health.trainSearch.reason ?? "열차 조회 연결이 없습니다"), outputSummary: health.trainSearch == .available ? "역 후보 정리됨" : "역 후보 대기"),
                step(key: "lookupTrain", title: "열차 조회", connectorID: "train_search", status: health.trainSearch == .available ? .succeeded : .failed(failureCode: "train_connector_unavailable"), outputSummary: health.trainSearch == .available ? "열차 조회 가능" : "열차 조회 불가", failureDetail: health.trainSearch.reason),
                step(key: "lookupMapTravelTime", title: "지도 이동 시간 확인", connectorID: "maps_search", status: health.mapsSearch == .available ? .succeeded : .skipped(reason: health.mapsSearch.reason ?? "지도 조회 연결이 없습니다"), outputSummary: health.mapsSearch == .available ? "지도 이동 시간 확인 가능" : "지도 이동 시간 미확인"),
                step(key: "composeItinerary", title: "이동 카드 생성", status: .succeeded, outputSummary: "이동 카드 준비됨")
            ]

        case .accountReview:
            return [
                step(key: "readLedger", title: "거래 자료 읽기", connectorID: "file_reader", status: hasTextAttachment ? .succeeded : .skipped(reason: "CSV/XLSX/영수증이 필요합니다"), outputSummary: hasTextAttachment ? "거래 자료 읽음" : "거래 자료 없음", sourceIDs: textAttachmentIDs),
                step(key: "normalizeRows", title: "행 정규화", status: hasTextAttachment ? .succeeded : .skipped(reason: "정규화할 자료가 없습니다"), outputSummary: hasTextAttachment ? "행 정규화됨" : "정규화 대기", sourceIDs: textAttachmentIDs),
                step(key: "findAnomalies", title: "이상 후보 찾기", status: hasTextAttachment ? .succeeded : .skipped(reason: "이상 후보를 찾을 자료가 없습니다"), outputSummary: hasTextAttachment ? "이상 후보 있음" : "이상 후보 없음", sourceIDs: textAttachmentIDs),
                step(key: "createSettlementCard", title: "정산 카드 생성", status: hasTextAttachment ? .succeeded : .skipped(reason: "정산 카드를 만들 자료가 없습니다"), outputSummary: hasTextAttachment ? "정산 카드 준비됨" : "정산 카드 불가", sourceIDs: textAttachmentIDs)
            ]

        case .research:
            return [
                step(key: "normalizeQuestion", title: "질문 정규화", status: .succeeded, outputSummary: "질문 정규화됨"),
                step(key: "gatherSources", title: "공개 출처 수집", connectorID: "web_search", status: concreteSources.isEmpty ? .failed(failureCode: "no_public_sources") : .succeeded, outputSummary: concreteSources.isEmpty ? "공개 출처 없음" : "\(concreteSources.count)개 출처", sourceIDs: allSourceIDs, failureDetail: concreteSources.isEmpty ? "no concrete public source" : nil),
                step(key: "splitClaims", title: "주장 분리", status: !concreteSources.isEmpty ? .succeeded : .skipped(reason: "출처가 필요합니다"), outputSummary: !concreteSources.isEmpty ? "주장 분리됨" : "주장 분리 대기", sourceIDs: allSourceIDs),
                step(key: "renderResearchCard", title: "리서치 카드 생성", status: !concreteSources.isEmpty ? .succeeded : .skipped(reason: "카드를 만들 출처가 없습니다"), outputSummary: !concreteSources.isEmpty ? "리서치 카드 준비됨" : "리서치 카드 불가", sourceIDs: allSourceIDs)
            ]
        }
    }

    private static func normalizedStockHint(from message: String) -> String? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(64))
    }

    private static func hasTextAttachment(_ attachment: ChatAttachment) -> Bool {
        guard let text = attachment.textContent?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !text.isEmpty
    }

    private static func mailBody(from userMessage: String, attachments: [ChatAttachment]) -> String {
        let attachmentText = attachments.compactMap { attachment -> String? in
            guard let text = attachment.textContent?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return text
        }
        let inlineBody = looksLikeMailBody(userMessage) ? userMessage : ""
        return [inlineBody, attachmentText.joined(separator: "\n")]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
    }

    private static func looksLikeMailBody(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lower = trimmed.lowercased()
        let lines = trimmed.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if lines.count >= 4 { return true }
        if lower.contains("subject:") || lower.contains("from:") || lower.contains("to:") || lower.contains("cc:") { return true }
        if lower.contains("안녕하세요") || lower.contains("감사합니다") || lower.contains("첨부") || lower.contains("회의") { return true }
        if lower.contains("@") && lower.contains(".") { return true }
        return trimmed.count >= 120 && (trimmed.contains(".") || trimmed.contains("!") || trimmed.contains("?"))
    }

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

    private static func isConcreteSource(_ sourceType: AgentWindowManager.SourceType) -> Bool {
        switch sourceType {
        case .quote, .news, .disclosure, .marketIndex, .webPage:
            return true
        case .userAttachment, .unknown:
            return false
        }
    }

    private static func isMarketSourceType(_ sourceType: AgentWindowManager.SourceType) -> Bool {
        switch sourceType {
        case .news, .disclosure, .marketIndex, .webPage:
            return true
        case .quote, .userAttachment, .unknown:
            return false
        }
    }

    private static func step(
        key: String,
        title: String,
        connectorID: String? = nil,
        detail: String? = nil,
        status: ChainStepStatus,
        outputSummary: String? = nil,
        sourceIDs: [String] = [],
        failureDetail: String? = nil
    ) -> ChainStep {
        let startedAt = Date()
        let finishedAt = startedAt.addingTimeInterval(0.02)
        return ChainStep(
            key: key,
            title: title,
            connectorID: connectorID,
            detail: detail,
            status: status,
            outputSummary: outputSummary,
            sourceIDs: sourceIDs,
            startedAt: startedAt,
            finishedAt: finishedAt,
            failureDetail: failureDetail
        )
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
