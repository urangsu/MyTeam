import Foundation

struct ToolInputSlot: Sendable, Codable, Equatable {
    let name: String
    let description: String
    let required: Bool
}

struct ToolSemanticManifest: Sendable, Codable, Equatable {
    let toolID: String
    let name: String
    let purpose: String
    let useWhen: [String]
    let doNotUseWhen: [String]
    let requiredInputs: [ToolInputSlot]
    let optionalInputs: [ToolInputSlot]
    let outputKind: String
    let positiveExamples: [String]
    let negativeExamples: [String]
    let permissionLevel: MyTeamPermissionLevel
    let credentialState: String
    let failureModes: [String]
}

struct AgenticWorkPlan: Sendable, Codable, Equatable {
    let title: String
    let userGoal: String
    let workType: String
    let targetEntities: [String]
    let clarificationQuestion: String?
    let steps: [AgenticToolStep]
    let compositionInstructions: String
    let userNotices: [String]
}

struct AgenticToolStep: Sendable, Codable, Equatable {
    let id: String
    let toolID: String
    let reason: String
    let inputs: [String: String]
    let required: Bool
    let failurePolicy: String
}

private struct AgenticPlannerResponse: Sendable, Codable, Equatable {
    let shouldUseTools: Bool
    let plan: AgenticWorkPlan?
    let clarificationQuestion: String?
}

enum ToolSemanticManifestCatalog {
    nonisolated static func manifests() -> [ToolSemanticManifest] {
        MyTeamToolRegistry.all
            .filter { $0.isImplemented && $0.isUserFacing }
            .filter { $0.category != .voice && $0.category != .system && $0.category != .mail }
            .compactMap(manifest(for:))
    }

    private nonisolated static func manifest(for descriptor: MyTeamToolDescriptor) -> ToolSemanticManifest? {
        let base = baseManifest(for: descriptor.id)
        return ToolSemanticManifest(
            toolID: descriptor.id,
            name: descriptor.displayName,
            purpose: base.purpose,
            useWhen: base.useWhen,
            doNotUseWhen: base.doNotUseWhen,
            requiredInputs: base.requiredInputs,
            optionalInputs: base.optionalInputs,
            outputKind: base.outputKind,
            positiveExamples: base.positiveExamples,
            negativeExamples: base.negativeExamples,
            permissionLevel: descriptor.permissionLevel,
            credentialState: descriptor.requiredCredential.map { _ in "connection_checked_by_app" } ?? "not_required",
            failureModes: base.failureModes
        )
    }

    private nonisolated static func baseManifest(for toolID: String) -> (
        purpose: String,
        useWhen: [String],
        doNotUseWhen: [String],
        requiredInputs: [ToolInputSlot],
        optionalInputs: [ToolInputSlot],
        outputKind: String,
        positiveExamples: [String],
        negativeExamples: [String],
        failureModes: [String]
    ) {
        let query = ToolInputSlot(name: "query", description: "사용자가 찾거나 정리하려는 대상", required: true)
        let displayCount = ToolInputSlot(name: "displayCount", description: "표시할 결과 수", required: false)
        let daysBack = ToolInputSlot(name: "daysBack", description: "조회할 과거 일수", required: false)

        switch toolID {
        case "news.search":
            return (
                "뉴스 검색 결과의 제목, 설명, 출처 링크를 기준으로 최근 이슈를 정리합니다.",
                ["최근 뉴스, 이슈, 동향, 기사 검색을 요청할 때", "회사나 산업의 외부 동향 확인이 필요할 때"],
                ["뉴스 기사처럼 써달라는 문체 요청", "기사체로 문장을 바꾸는 요청", "보도자료 초안을 작성하는 요청"],
                [query],
                [displayCount],
                "news_search_result",
                ["삼성전자 뉴스 찾아줘", "리튬 관련 최신 뉴스"],
                ["뉴스 기사처럼 써줘", "기사체로 바꿔줘"],
                ["no_results", "credential_missing", "provider_unavailable"]
            )
        case "dart.disclosures.search":
            return (
                "DART 공식 공시 목록과 원문 링크를 조회합니다.",
                ["회사 공시, DART, 사업보고서, 최근 제출 문서를 요청할 때"],
                ["공시 양식처럼 문서를 작성해 달라는 요청", "공시 문체로 바꾸는 요청"],
                [query],
                [daysBack, displayCount],
                "disclosure_result",
                ["삼성전자 공시사항 보여줘", "005930 DART"],
                ["공시 양식처럼 써줘"],
                ["connection_required", "no_results", "provider_unavailable"]
            )
        case "finance.krx.stockPrice":
            return (
                "공공데이터 기준일 주식 시세를 조회합니다. 실시간 시세가 아닙니다.",
                ["주가, 시세, 종가, 거래량을 기준일 데이터로 확인할 때"],
                ["주가처럼 변동표를 만들어 달라는 문서 형식 요청", "매수나 매도 판단 요청"],
                [query],
                [],
                "public_finance_stock_price",
                ["삼성전자 주가 알려줘", "005930 시세"],
                ["주가처럼 표 만들어줘", "매수 추천해줘"],
                ["no_results", "provider_unavailable"]
            )
        case "finance.krx.index":
            return (
                "코스피, 코스닥, KRX300 등 기준일 시장 지수를 조회합니다.",
                ["시장 지수 맥락이 필요할 때", "코스피나 코스닥 지수를 함께 보려 할 때"],
                ["지수 형식으로 문서를 꾸미는 요청"],
                [query],
                [],
                "public_finance_index",
                ["코스피 지수 확인", "삼성전자 주가랑 코스피"],
                ["지수처럼 문장 써줘"],
                ["no_results", "provider_unavailable"]
            )
        case "finance.company.statement":
            return (
                "회사명이나 종목코드로 기업 재무 요약을 조회합니다.",
                ["재무상황, 재무제표, 손익, 매출, 비용 요약이 필요할 때"],
                ["재무제표 양식만 작성하려는 요청"],
                [query],
                [],
                "public_finance_statement",
                ["삼성전자 재무상황", "포스코홀딩스 재무요약"],
                ["재무제표처럼 문장 써줘"],
                ["no_results", "identity_required", "provider_unavailable"]
            )
        case "weather.current":
            return (
                "기상청 기준 날씨와 예보 정보를 조회합니다.",
                ["출장, 외근, 현장작업, 오늘 날씨, 지역 예보가 필요할 때"],
                ["날씨처럼 감성 문구를 쓰는 요청"],
                [query],
                [],
                "weather_result",
                ["광양 출장 날씨", "포항 현장작업 날씨"],
                ["날씨처럼 문장 써줘"],
                ["credential_invalid", "region_unknown", "provider_unavailable"]
            )
        case "law.search":
            return (
                "공식 출처 기반 법령과 조문 후보를 검색합니다.",
                ["법령, 조문, 근로기준법, 산안법, 연차, 주52시간 등 공식 법령 확인이 필요할 때"],
                ["법적으로 자연스럽게 문장을 다듬는 요청", "법률 자문이나 결론 단정을 요구하는 요청"],
                [query],
                [displayCount],
                "law_search_result",
                ["근로기준법 연차 조문 찾아줘"],
                ["법적으로 자연스럽게 써줘"],
                ["no_results", "provider_unavailable"]
            )
        case "calendar.events.today":
            return (
                "Google Calendar 읽기 연결로 오늘 일정을 확인합니다.",
                ["오늘 일정, 내일 일정, 회의 준비, 캘린더 확인이 필요할 때"],
                ["캘린더 형식으로 문서를 정리하는 요청"],
                [query],
                [],
                "calendar_events",
                ["오늘 일정 확인해줘", "회의 준비할 것 봐줘"],
                ["캘린더 형식으로 정리해줘"],
                ["connection_required", "permission_denied"]
            )
        case "document.meetingMinutes":
            return (
                "회의 메모나 녹취록을 결정사항, 지시사항, 담당자, 기한 중심으로 정리합니다.",
                ["회의록, 녹취록, 지시사항, 결정사항, 담당자, 기한을 추출할 때"],
                ["회의록 양식 설명만 원하는 요청"],
                [query],
                [],
                "document_draft",
                ["이 회의록에서 지시사항 뽑아줘"],
                ["회의록처럼 문장 써줘"],
                ["input_required"]
            )
        case "document.rewrite":
            return (
                "문장이나 문서를 목적에 맞게 다듬습니다.",
                ["보고문구, 임원 보고용, 짧게 바꾸기, 문체 변환, 체크리스트 변환이 필요할 때"],
                ["외부 최신 정보 조회가 필요한 요청"],
                [query],
                [],
                "document_draft",
                ["이걸 임원 보고용으로 짧게 바꿔줘", "뉴스 기사처럼 써줘"],
                ["삼성전자 뉴스 찾아줘"],
                ["input_required"]
            )
        case "spreadsheet.postprocess":
            return (
                "붙여넣은 표나 스프레드시트 내용을 기준으로 정리, 검산, 이상 항목 확인 계획을 만듭니다.",
                ["표 정리, 엑셀 정리, 예산안 이상 항목, 중복, 누락, 검산이 필요할 때"],
                ["Google Sheets에서 실제 값을 읽어와야 하는 요청"],
                [query],
                [],
                "spreadsheet_review_plan",
                ["이 예산안 이상한 항목 찾아줘", "이 표 중복 확인해줘"],
                ["구글시트 읽어줘"],
                ["input_required"]
            )
        case "spreadsheet.googleSheets.read":
            return (
                "Google Sheets URL 또는 ID에서 값을 읽어옵니다.",
                ["구글시트 URL이나 ID에서 실제 값을 읽어오라고 할 때"],
                ["붙여넣은 표 자체를 정리하는 요청", "시트 형식으로 문서를 쓰는 요청"],
                [query],
                [],
                "spreadsheet_values",
                ["https://docs.google.com/spreadsheets/d/... 읽어줘"],
                ["시트처럼 정리해줘"],
                ["connection_required", "permission_denied", "invalid_id"]
            )
        default:
            return (
                "업무 도구를 실행합니다.",
                ["사용자가 해당 업무를 명시적으로 요청할 때"],
                ["문체나 양식만 바꾸는 요청"],
                [query],
                [],
                "tool_result",
                [],
                [],
                ["unavailable"]
            )
        }
    }
}

enum ToolPlanningPromptBuilder {
    static func build(userMessage: String, context: NaturalWorkContext, manifests: [ToolSemanticManifest]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let manifestJSON = (try? String(data: encoder.encode(manifests), encoding: .utf8)) ?? "[]"
        let attachmentNames = context.pendingAttachments.map(\.fileName).joined(separator: ", ")
        let recentText = String(context.recentText.prefix(1_500))

        return """
        You are MyTeam's internal work planner. Return JSON only.
        The app executes tools after validation. Do not claim execution.

        User message:
        \(userMessage)

        Context:
        - attachments: \(attachmentNames.isEmpty ? "none" : attachmentNames)
        - recent conversation excerpt:
        \(recentText.isEmpty ? "none" : recentText)

        Available tools:
        \(manifestJSON)

        Output schema:
        {
          "shouldUseTools": true,
          "plan": {
            "title": "short Korean title",
            "userGoal": "Korean summary of goal",
            "workType": "companyBriefing|newsBriefing|schedulePreparation|lawIssueReview|reportDraft|meetingMinutes|tableCleanupPlan|budgetReview|closingVarianceAnalysis|fileSummary|disclosureReview",
            "targetEntities": ["..."],
            "clarificationQuestion": null,
            "steps": [
              {
                "id": "stable-step-id",
                "toolID": "manifest toolID only",
                "reason": "why this tool is needed",
                "inputs": {"query": "...", "displayCount": "5", "daysBack": "30"},
                "required": false,
                "failurePolicy": "partial|required"
              }
            ],
            "compositionInstructions": "how to combine results",
            "userNotices": ["..."]
          },
          "clarificationQuestion": null
        }

        Rules:
        - Use only manifest toolID values.
        - If the user only asks for writing style or format, use document.rewrite, not external lookup tools.
        - "뉴스 기사처럼 써줘" is writing, not news search.
        - "캘린더 형식으로 정리해줘" is writing, not calendar lookup.
        - "공시 양식처럼 써줘" is writing, not DART lookup.
        - "주가처럼 변동표 만들어줘" is writing or table work, not stock lookup.
        - "법적으로 자연스럽게 써줘" is writing, not law search.
        - Financial data is public 기준일 data, not real-time quotes.
        - Do not recommend buy/sell actions.
        - Legal output is search/reference only, not legal advice.
        - If no tool is needed, return {"shouldUseTools": false, "plan": null, "clarificationQuestion": null}.
        """
    }
}

enum AgenticToolOrchestrator {
    static func plan(
        for message: String,
        context: NaturalWorkContext,
        chatHistory: [AgentWindowManager.ChatLog],
        agentID: String,
        agentConfig: AgentWindowManager.AgentConfig?,
        requestID: UUID = UUID()
    ) async -> NaturalWorkPlan? {
        guard isLikelyWorkRequest(message, context: context) else {
            return NaturalWorkRouter.plan(for: message, context: context)
        }

        let fallback = NaturalWorkRouter.plan(for: message, context: context)
        let manifests = ToolSemanticManifestCatalog.manifests()
        guard !manifests.isEmpty else { return fallback }

        let preferred = agentConfig?.llmProvider
            ?? UserDefaults.standard.string(forKey: "defaultLLMProvider").flatMap(LLMProvider.init(rawValue:))
            ?? .gemini
        guard !AIService.shared.providerCandidates(preferred: preferred, requiresToolUse: true).isEmpty else {
            return fallback
        }

        do {
            let prompt = ToolPlanningPromptBuilder.build(
                userMessage: message,
                context: context,
                manifests: manifests
            )
            let response = try await AIService.shared.getResponse(
                text: prompt,
                agentID: agentID,
                chatHistory: chatHistory,
                agentConfig: agentConfig,
                requiresToolUse: true,
                requestID: requestID,
                toolDescriptorCount: manifests.count,
                fileContextCharacters: context.attachmentText.count,
                selectedAgentCount: 1
            )
            guard let plannerResponse = decodePlannerResponse(response.text),
                  plannerResponse.shouldUseTools,
                  let workPlan = plannerResponse.plan else {
                return fallback
            }
            return ToolPlanValidator.validate(
                workPlan,
                originalText: message,
                context: context,
                manifests: manifests
            ) ?? fallback
        } catch {
            AppLog.warning("[AgenticToolOrchestrator] planning failed: \(error.localizedDescription)")
            return fallback
        }
    }

    private static func decodePlannerResponse(_ text: String) -> AgenticPlannerResponse? {
        let decoder = JSONDecoder()
        let candidates = jsonObjectCandidates(from: text)
        for candidate in candidates {
            guard let data = candidate.data(using: .utf8) else { continue }
            if let response = try? decoder.decode(AgenticPlannerResponse.self, from: data) {
                return response
            }
            if let directPlan = try? decoder.decode(AgenticWorkPlan.self, from: data) {
                return AgenticPlannerResponse(
                    shouldUseTools: !directPlan.steps.isEmpty,
                    plan: directPlan,
                    clarificationQuestion: directPlan.clarificationQuestion
                )
            }
        }
        return nil
    }

    private static func jsonObjectCandidates(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var candidates: [String] = []
        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
            candidates.append(trimmed)
        }
        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}"),
           start < end {
            candidates.append(String(trimmed[start...end]))
        }
        return Array(NSOrderedSet(array: candidates).compactMap { $0 as? String })
    }

    private static func isLikelyWorkRequest(_ message: String, context: NaturalWorkContext) -> Bool {
        let lower = message.lowercased()
        if !context.pendingAttachments.isEmpty { return true }
        let cues = [
            "알려줘", "봐줘", "정리", "조회", "확인", "브리핑", "보고", "뉴스", "공시",
            "주가", "시세", "재무", "날씨", "일정", "캘린더", "법령", "조문", "회의록",
            "예산", "결산", "표", "엑셀", "구글시트", "첨부파일", "핵심만", "임원용"
        ]
        return cues.contains { lower.contains($0) }
    }
}

enum ToolPlanValidator {
    static func validate(
        _ workPlan: AgenticWorkPlan,
        originalText: String,
        context: NaturalWorkContext,
        manifests: [ToolSemanticManifest]
    ) -> NaturalWorkPlan? {
        let manifestIDs = Set(manifests.map(\.toolID))
        var steps: [NaturalToolStep] = []
        var missing: [NaturalMissingSection] = []

        for plannedStep in workPlan.steps.prefix(8) {
            guard manifestIDs.contains(plannedStep.toolID),
                  let descriptor = MyTeamToolRegistry.descriptor(id: plannedStep.toolID),
                  descriptor.isImplemented,
                  descriptor.isUserFacing else {
                missing.append(NaturalMissingSection(
                    title: plannedStep.reason.isEmpty ? "요청 항목" : plannedStep.reason,
                    reason: "현재 앱에서 실행할 수 없는 항목입니다.",
                    nextAction: "다른 방식으로 요청하거나 필요한 연결을 확인하세요."
                ))
                continue
            }

            guard descriptor.permissionLevel == .readOnly || descriptor.permissionLevel == .draftOnly else {
                missing.append(NaturalMissingSection(
                    title: descriptor.displayName,
                    reason: "사용자 승인 없이 실행할 수 없는 작업입니다.",
                    nextAction: "승인이 필요한 작업은 별도 확인 후 실행하세요."
                ))
                continue
            }

            guard !isFalsePositive(toolID: plannedStep.toolID, originalText: originalText) else {
                continue
            }

            let query = normalizedQuery(for: plannedStep, originalText: originalText, context: context)
            guard !query.isEmpty else {
                missing.append(NaturalMissingSection(
                    title: descriptor.displayName,
                    reason: "실행에 필요한 입력이 부족합니다.",
                    nextAction: "대상, 파일, 표, 또는 검색어를 추가로 알려주세요."
                ))
                continue
            }

            steps.append(NaturalToolStep(
                id: plannedStep.id.isEmpty ? descriptor.id : plannedStep.id,
                toolID: descriptor.id,
                input: MyTeamToolInput(
                    query: query,
                    daysBack: intValue(plannedStep.inputs["daysBack"]),
                    displayCount: intValue(plannedStep.inputs["displayCount"])
                ),
                required: plannedStep.required,
                sectionTitle: descriptor.displayName,
                failurePolicy: plannedStep.failurePolicy == "required" ? .required : .partial
            ))
        }

        guard !steps.isEmpty || !missing.isEmpty else { return nil }

        return NaturalWorkPlan(
            request: NaturalWorkRequest(
                originalText: originalText,
                entities: workPlan.targetEntities.map { .documentType($0) },
                intents: intents(for: workPlan.workType, steps: steps),
                confidence: .medium,
                clarificationQuestion: workPlan.clarificationQuestion
            ),
            workType: naturalWorkType(from: workPlan.workType),
            title: workPlan.title.isEmpty ? "업무 확인" : workPlan.title,
            userFacingSummary: "요청을 여러 항목으로 나누어 확인 중입니다.",
            steps: steps,
            compositionStyle: steps.count > 1 ? .compositeBriefing : .singleTopic,
            userNotice: workPlan.userNotices.first,
            preflightMissingSections: missing
        )
    }

    private static func normalizedQuery(
        for step: AgenticToolStep,
        originalText: String,
        context: NaturalWorkContext
    ) -> String {
        if let query = step.inputs["query"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !query.isEmpty {
            return query
        }
        if step.toolID == "document.rewrite" || step.toolID == "document.meetingMinutes" || step.toolID == "spreadsheet.postprocess" {
            let attachment = context.attachmentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !attachment.isEmpty { return "\(originalText)\n\n\(attachment)" }
            if !context.recentText.isEmpty { return "\(originalText)\n\n최근 대화:\n\(context.recentText)" }
        }
        return originalText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isFalsePositive(toolID: String, originalText: String) -> Bool {
        let lower = originalText.lowercased()
        switch toolID {
        case "news.search":
            return containsAny(lower, ["뉴스 기사처럼", "기사체", "보도자료 문구", "보도자료처럼"])
        case "calendar.events.today":
            return containsAny(lower, ["캘린더 형식", "캘린더처럼"])
        case "dart.disclosures.search":
            return containsAny(lower, ["공시 양식", "공시처럼"])
        case "finance.krx.stockPrice", "finance.krx.index":
            return containsAny(lower, ["주가처럼", "시세처럼", "매수 추천", "매도 추천", "투자 추천"])
        case "law.search":
            return containsAny(lower, ["법적으로 자연스럽게", "법적으로 써줘", "법률 자문"])
        default:
            return false
        }
    }

    private static func naturalWorkType(from rawValue: String) -> NaturalWorkType {
        NaturalWorkType(rawValue: rawValue) ?? .reportDraft
    }

    private static func intents(for workType: String, steps: [NaturalToolStep]) -> [NaturalIntent] {
        var intents: [NaturalIntent] = []
        switch naturalWorkType(from: workType) {
        case .companyBriefing:
            intents.append(.companyOverview)
        case .meetingMinutes:
            intents.append(.meetingMinutes)
        case .reportDraft:
            intents.append(.documentDraft)
        case .budgetReview:
            intents.append(.budgetReview)
        case .closingVarianceAnalysis:
            intents.append(.closingVarianceAnalysis)
        case .tableCleanupPlan:
            intents.append(.tableCleanupPlan)
        case .lawIssueReview:
            intents.append(.law)
        case .schedulePreparation:
            intents.append(.schedulePreparation)
        case .newsBriefing:
            intents.append(.news)
        case .disclosureReview:
            intents.append(.disclosure)
        case .evidenceCheck:
            intents.append(.evidenceCheck)
        case .fileSummary:
            intents.append(.fileSummary)
        }
        for step in steps {
            switch step.toolID {
            case "news.search": intents.append(.news)
            case "dart.disclosures.search": intents.append(.disclosure)
            case "finance.krx.stockPrice", "finance.krx.index": intents.append(.stockPrice)
            case "finance.company.statement": intents.append(.companyFinance)
            case "weather.current": intents.append(.weather)
            case "law.search": intents.append(.law)
            case "calendar.events.today": intents.append(.schedulePreparation)
            case "document.meetingMinutes": intents.append(.meetingMinutes)
            case "document.rewrite": intents.append(.documentDraft)
            case "spreadsheet.postprocess": intents.append(.tableCleanupPlan)
            default: break
            }
        }
        var seen = Set<NaturalIntent>()
        return intents.filter { seen.insert($0).inserted }
    }

    private static func intValue(_ text: String?) -> Int? {
        guard let text else { return nil }
        return Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0.lowercased()) }
    }
}
