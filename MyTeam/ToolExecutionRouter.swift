import Foundation

actor ToolExecutionRouter {
    static let shared = ToolExecutionRouter()

    func readiness(for descriptor: MyTeamToolDescriptor) async -> ToolExecutionState {
        guard FeatureGate.allows(descriptor) else {
            return .unavailable(distributionMessage(for: descriptor))
        }

        guard descriptor.isImplemented else {
            return .unavailable("이 기능은 준비 중입니다.")
        }

        if let requirement = descriptor.requiredCredential {
            let health = await MainActor.run {
                CredentialHealthService.shared.health(for: requirement.provider)
            }
            switch health.state {
            case .notConnected:
                return .needsConnection(requirement.provider)
            case .untested, .testUnavailable:
                return .needsValidation(requirement.provider)
            case .testFailed:
                return .failed(MyTeamToolFailure(
                    title: "연결 확인 실패",
                    message: "키 권한 또는 발급 상태를 확인하세요.",
                    recoveryActions: [
                        MyTeamNextAction(id: "openConnection", title: "연결 설정", role: .normal)
                    ]
                ))
            case .connected:
                break
            }
        }

        let decision = ToolPermissionPolicy.decision(for: descriptor.permissionLevel)
        if decision.requiresApproval {
            return .needsApproval(decision.userFacingReason)
        }

        return .idle
    }

    func run(_ descriptor: MyTeamToolDescriptor) async -> ToolExecutionState {
        await run(descriptor, input: MyTeamToolInput())
    }

    func run(_ descriptor: MyTeamToolDescriptor, input: MyTeamToolInput) async -> ToolExecutionState {
        await run(descriptor, input: input, bypassApproval: false)
    }

    func run(_ descriptor: MyTeamToolDescriptor, input: MyTeamToolInput, bypassApproval: Bool) async -> ToolExecutionState {
        let logID = await MainActor.run {
            ToolExecutionLogStore.shared.start(descriptor: descriptor)
        }
        let state = await readiness(for: descriptor, bypassApproval: bypassApproval)
        guard state.isRunnable else {
            await finishLog(id: logID, state: state)
            return state
        }

        let result: ToolExecutionState
        switch descriptor.id {
        case "briefing.today":
            result = await runTodayBriefing()
        case "document.meetingMinutes":
            result = await runUniversalDocument(type: .meetingMinutes, input: input)
        case "document.rewrite":
            result = await runUniversalDocument(type: .summary, input: input)
        case "spreadsheet.postprocess":
            result = runSpreadsheetPostprocess(input: input)
        case "spreadsheet.googleSheets.read":
            result = await runGoogleSheetsRead(input: input)
        case "calendar.events.today":
            result = await runGoogleCalendarToday()
        case "dart.disclosures.search":
            result = await runDART(input: input)
        case "news.search":
            result = await runNaverNews(input: input)
        case "weather.current":
            result = await runKMAWeather(input: input)
        case "law.search":
            result = await runKoreanLaw(input: input)
        default:
            result = .unavailable("이 업무는 아직 실행 연결 전입니다.")
        }
        await finishLog(id: logID, state: result)
        return result
    }

    private func readiness(for descriptor: MyTeamToolDescriptor, bypassApproval: Bool) async -> ToolExecutionState {
        let state = await readiness(for: descriptor)
        guard case .needsApproval = state, bypassApproval else { return state }
        return .idle
    }

    private func finishLog(id: UUID, state: ToolExecutionState) async {
        await MainActor.run {
            ToolExecutionLogStore.shared.finish(id: id, state: state)
        }
    }

    private func runTodayBriefing() async -> ToolExecutionState {
        let snapshot = await MainActor.run {
            DailyBriefingLocalProvider.makeSnapshot(
                roomID: AgentWindowManager.shared.currentRoomID,
                manager: .shared
            )
        }
        let body = localBriefingBody(from: snapshot)
        return .succeeded(MyTeamToolResult(
            title: "오늘 브리핑을 준비했습니다",
            summary: snapshot.summary,
            sourceLabel: "로컬 작업 상태",
            body: body,
            items: localBriefingItems(from: snapshot),
            nextActions: [
                MyTeamNextAction(id: "searchAgain", title: "새로고침", role: .normal)
            ]
        ))
    }

    private func runUniversalDocument(type: UniversalDocumentSkillType, input: MyTeamToolInput) async -> ToolExecutionState {
        let fallback = type == .meetingMinutes ? "회의 내용을 붙여넣으면 회의록 초안을 만듭니다." : "다듬을 문장이나 문서 내용을 붙여넣으세요."
        let source = sanitizedQuery(input.query, fallback: fallback)
        let documentPayload = await MainActor.run {
            let request = UniversalDocumentSkillService.extractRequest(
                from: source,
                type: type,
                sourceText: source,
                sourceName: "업무 카드 입력"
            )
            return (
                displayName: type.displayName,
                body: UniversalDocumentSkillService.documentBody(for: request),
                sections: UniversalDocumentSkillService.requiredSections(for: type)
            )
        }
        return .succeeded(MyTeamToolResult(
            title: "\(documentPayload.displayName) 초안을 만들었습니다",
            summary: "파일 저장 없이 바로 편집 가능한 Markdown 초안을 생성했습니다.",
            sourceLabel: "MyTeam 로컬 문서 런타임",
            body: documentPayload.body,
            items: documentPayload.sections.prefix(5).enumerated().map { index, section in
                MyTeamToolResultItem(
                    id: "\(type.rawValue)-\(index)",
                    title: section,
                    subtitle: "초안에 포함된 섹션입니다.",
                    metadata: nil,
                    sourceURL: nil
                )
            },
            nextActions: [
                MyTeamNextAction(id: "changeKeyword", title: "다시 작성", role: .normal)
            ]
        ))
    }

    private func runSpreadsheetPostprocess(input: MyTeamToolInput) -> ToolExecutionState {
        let source = sanitizedQuery(input.query, fallback: "표 내용을 붙여넣으면 정리 계획을 만듭니다.")
        let rows = source
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let columnGuess = rows.map(estimatedColumnCount).max() ?? 0
        let body = spreadsheetPostprocessBody(source: source, rowCount: rows.count, columnGuess: columnGuess)
        return .succeeded(MyTeamToolResult(
            title: "엑셀 후처리 계획을 만들었습니다",
            summary: "입력된 표/메모를 기준으로 정리, 검산, 보고용 변환 단계를 제안했습니다.",
            sourceLabel: "MyTeam 로컬 스프레드시트 런타임",
            body: body,
            items: [
                MyTeamToolResultItem(
                    id: "rows",
                    title: "감지한 행",
                    subtitle: "\(rows.count)개",
                    metadata: rows.isEmpty ? "붙여넣은 표가 없으면 기본 계획만 생성합니다." : nil,
                    sourceURL: nil
                ),
                MyTeamToolResultItem(
                    id: "columns",
                    title: "추정 열",
                    subtitle: columnGuess > 0 ? "\(columnGuess)개" : "미확인",
                    metadata: "탭, 쉼표, 파이프 구분자를 기준으로 추정합니다.",
                    sourceURL: nil
                )
            ],
            nextActions: [
                MyTeamNextAction(id: "changeKeyword", title: "다시 정리", role: .normal)
            ]
        ))
    }

    private func runGoogleSheetsRead(input: MyTeamToolInput) async -> ToolExecutionState {
        let hasSheetsToken = await MainActor.run {
            GoogleOAuthTokenStore.shared.hasToken(for: .googleSheets)
        }
        guard hasSheetsToken else {
            return .failed(MyTeamToolFailure(
                title: "Google Sheets 연결이 필요합니다",
                message: "스프레드시트를 읽으려면 비서 연결에서 Google Sheets 읽기 연결을 먼저 완료하세요.",
                recoveryActions: [
                    MyTeamNextAction(id: "openAssistantConnection", title: "비서 연결", role: .normal)
                ]
            ))
        }

        guard let request = googleSheetsReadRequest(from: input.query) else {
            return .failed(MyTeamToolFailure(
                title: "스프레드시트 ID가 필요합니다",
                message: "Google Sheets URL 또는 spreadsheetId를 입력해 주세요. 범위는 입력하지 않으면 Sheet1!A1:Z100으로 조회합니다.",
                recoveryActions: [
                    MyTeamNextAction(id: "changeKeyword", title: "다시 입력", role: .normal)
                ]
            ))
        }

        do {
            let result = try await GoogleSheetsClient.shared.fetchValues(
                spreadsheetID: request.spreadsheetID,
                range: request.range
            )
            if result.values.isEmpty {
                return .succeeded(MyTeamToolResult(
                    title: "시트 값이 없습니다",
                    summary: "\(result.range) 범위에서 값을 찾지 못했습니다.",
                    sourceLabel: "Google Sheets 읽기",
                    body: nil,
                    items: [],
                    nextActions: [
                        MyTeamNextAction(id: "changeKeyword", title: "범위 바꾸기", role: .normal)
                    ]
                ))
            }

            return .succeeded(MyTeamToolResult(
                title: "Google Sheets 값을 읽었습니다",
                summary: "\(result.range) 범위에서 \(result.rowCount)행, \(result.columnCount)열을 가져왔습니다.",
                sourceLabel: "Google Sheets 읽기",
                body: googleSheetsTableBody(result),
                items: [
                    MyTeamToolResultItem(
                        id: "rows",
                        title: "행",
                        subtitle: "\(result.rowCount)개",
                        metadata: "최대 20행 미리보기",
                        sourceURL: nil
                    ),
                    MyTeamToolResultItem(
                        id: "columns",
                        title: "열",
                        subtitle: "\(result.columnCount)개",
                        metadata: result.range,
                        sourceURL: nil
                    )
                ],
                nextActions: [
                    MyTeamNextAction(id: "changeKeyword", title: "다른 시트 읽기", role: .normal)
                ]
            ))
        } catch {
            return googleSheetsFailureState(error)
        }
    }

    private func runGoogleCalendarToday() async -> ToolExecutionState {
        let hasToken = await MainActor.run {
            GoogleOAuthTokenStore.shared.hasToken(for: .googleCalendar)
        }
        guard hasToken else {
            return .failed(MyTeamToolFailure(
                title: "Google Calendar 연결이 필요합니다",
                message: "오늘 일정을 가져오려면 비서 연결에서 Google Calendar 읽기 연결을 먼저 완료하세요.",
                recoveryActions: [
                    MyTeamNextAction(id: "openAssistantConnection", title: "비서 연결", role: .normal)
                ]
            ))
        }

        let now = Date()
        let items = await GoogleDailyBriefingCalendarProvider.shared.calendarItemsForToday(now: now)
        let calendarStatus = await MainActor.run {
            (
                message: GoogleDailyBriefingCalendarProvider.shared.statusMessage,
                fetchStatus: GoogleDailyBriefingCalendarProvider.shared.lastFetchStatus
            )
        }
        if items.isEmpty, calendarStatus.fetchStatus != "empty" {
            return calendarFailureState(
                fetchStatus: calendarStatus.fetchStatus,
                message: calendarStatus.message
            )
        }
        if items.isEmpty {
            return .succeeded(MyTeamToolResult(
                title: "오늘 일정이 없습니다",
                summary: calendarStatus.message,
                sourceLabel: "Google Calendar",
                body: nil,
                items: [],
                nextActions: [
                    MyTeamNextAction(id: "searchAgain", title: "새로고침", role: .normal)
                ]
            ))
        }

        return .succeeded(MyTeamToolResult(
            title: "오늘 일정을 가져왔습니다",
            summary: calendarStatus.message,
            sourceLabel: "Google Calendar",
            body: calendarBody(from: items),
            items: items.prefix(5).map { item in
                MyTeamToolResultItem(
                    id: item.id.uuidString,
                    title: item.title,
                    subtitle: [item.timeText, item.location].compactMap { $0 }.joined(separator: " · "),
                    metadata: "Google Calendar",
                    sourceURL: nil
                )
            },
            nextActions: [
                MyTeamNextAction(id: "searchAgain", title: "새로고침", role: .normal)
            ]
        ))
    }

    private func runDART(input: MyTeamToolInput) async -> ToolExecutionState {
        let provider = ExternalProvider.dartDisclosure
        guard let apiKey = await credentialValue(provider: provider, fieldID: "apiKey") else {
            return .needsConnection(provider)
        }
        let query = sanitizedQuery(input.query, fallback: "포스코")
        let daysBack = min(max(input.daysBack ?? 30, 1), 365)

        do {
            let items = try await DARTDisclosureDirectConnector.recentDisclosures(
                query: query,
                apiKey: apiKey,
                daysBack: daysBack
            )
            if items.isEmpty {
                return .succeeded(MyTeamToolResult(
                    title: "최근 공시가 없습니다",
                    summary: "'\(query)' 기준 최근 \(daysBack)일 공시를 찾지 못했습니다.",
                    sourceLabel: "DART 공시",
                    body: nil,
                    items: [],
                    nextActions: [
                        MyTeamNextAction(id: "extendRange", title: "기간 늘리기", role: .normal),
                        MyTeamNextAction(id: "changeKeyword", title: "키워드 바꾸기", role: .normal),
                        MyTeamNextAction(id: "checkConnection", title: "연결 확인", role: .normal)
                    ]
                ))
            }

            return .succeeded(MyTeamToolResult(
                title: "최근 공시를 찾았습니다",
                summary: "최근 \(daysBack)일 기준 공시 \(items.count)건을 찾았습니다.",
                sourceLabel: "DART 공시",
                body: nil,
                items: items.prefix(5).map { item in
                    MyTeamToolResultItem(
                        id: item.receiptNumber,
                        title: item.reportName,
                        subtitle: item.corporationName,
                        metadata: "접수일 \(item.receiptDate)",
                        sourceURL: item.sourceURL
                    )
                },
                nextActions: [
                    MyTeamNextAction(id: "summarize", title: "요약하기", role: .normal),
                    MyTeamNextAction(id: "draftReport", title: "보고서 문단", role: .normal),
                    MyTeamNextAction(id: "searchAgain", title: "다시 검색", role: .normal)
                ]
            ))
        } catch {
            return failureState(error, provider: provider)
        }
    }

    private func runNaverNews(input: MyTeamToolInput) async -> ToolExecutionState {
        let provider = ExternalProvider.naverNews
        guard
            let clientID = await credentialValue(provider: provider, fieldID: "clientID"),
            let clientSecret = await credentialValue(provider: provider, fieldID: "clientSecret")
        else {
            return .needsConnection(provider)
        }
        let query = sanitizedQuery(input.query, fallback: "경제")
        let displayCount = min(max(input.displayCount ?? 5, 1), 10)

        do {
            let items = try await NaverNewsDirectConnector.search(
                query: query,
                clientID: clientID,
                clientSecret: clientSecret,
                display: displayCount
            )
            if items.isEmpty {
                return .succeeded(MyTeamToolResult(
                    title: "뉴스가 없습니다",
                    summary: "'\(query)' 기준 최신 뉴스를 찾지 못했습니다.",
                    sourceLabel: "Naver News",
                    body: nil,
                    items: [],
                    nextActions: [
                        MyTeamNextAction(id: "changeKeyword", title: "키워드 바꾸기", role: .normal),
                        MyTeamNextAction(id: "checkConnection", title: "연결 확인", role: .normal)
                    ]
                ))
            }

            return .succeeded(MyTeamToolResult(
                title: "뉴스를 찾았습니다",
                summary: "최신 뉴스 \(items.count)건을 가져왔습니다.",
                sourceLabel: "Naver News",
                body: nil,
                items: items.prefix(5).map { item in
                    MyTeamToolResultItem(
                        id: (item.originalLink ?? item.link).absoluteString,
                        title: item.title,
                        subtitle: item.description,
                        metadata: item.publishedAt.map(Self.displayDate) ?? "발행일 미확인",
                        sourceURL: item.originalLink ?? item.link
                    )
                },
                nextActions: [
                    MyTeamNextAction(id: "summarize", title: "요약하기", role: .normal),
                    MyTeamNextAction(id: "draftEvidence", title: "근거 정리", role: .normal),
                    MyTeamNextAction(id: "searchAgain", title: "다시 검색", role: .normal)
                ]
            ))
        } catch {
            return failureState(error, provider: provider)
        }
    }

    private func runKMAWeather(input: MyTeamToolInput) async -> ToolExecutionState {
        let provider = ExternalProvider.kmaWeather
        guard let serviceKey = await credentialValue(provider: provider, fieldID: "serviceKey") else {
            return .needsConnection(provider)
        }
        guard let region = KMARegionGridMapper.resolve(input.query) else {
            return .failed(MyTeamToolFailure(
                title: "지역 격자를 찾지 못했습니다",
                message: KMARegionGridMapper.userFacingUnsupportedMessage(for: input.query),
                recoveryActions: [
                    MyTeamNextAction(id: "changeKeyword", title: "지역 바꾸기", role: .normal)
                ]
            ))
        }
        let nx = input.nx ?? region.nx
        let ny = input.ny ?? region.ny

        do {
            let observations = try await KMAWeatherDirectConnector.ultraShortNowcast(
                serviceKey: serviceKey,
                nx: nx,
                ny: ny
            )
            let summaryParts = weatherSummaryParts(from: observations)
            return .succeeded(MyTeamToolResult(
                title: "현재 날씨를 확인했습니다",
                summary: summaryParts.isEmpty
                    ? "기상청 초단기실황 \(observations.count)개 항목을 가져왔습니다."
                    : summaryParts.joined(separator: " · "),
                sourceLabel: "기상청 초단기실황",
                body: nil,
                items: observations.prefix(5).map { observation in
                    MyTeamToolResultItem(
                        id: "\(observation.category)-\(observation.baseDate)-\(observation.baseTime)",
                        title: weatherTitle(for: observation.category),
                        subtitle: "\(observation.value)\(weatherUnit(for: observation.category))",
                        metadata: "\(region.name) · 기준 \(observation.baseDate) \(observation.baseTime) · 격자 \(nx),\(ny)",
                        sourceURL: kmaOfficialURL()
                    )
                },
                nextActions: [
                    MyTeamNextAction(id: "searchAgain", title: "다시 조회", role: .normal),
                    MyTeamNextAction(id: "checkConnection", title: "연결 확인", role: .normal)
                ]
            ))
        } catch {
            return failureState(error, provider: provider)
        }
    }

    private func runKoreanLaw(input: MyTeamToolInput) async -> ToolExecutionState {
        let provider = ExternalProvider.koreanLaw
        guard let lawOC = await credentialValue(provider: provider, fieldID: "lawOC") else {
            return .needsConnection(provider)
        }
        let query = sanitizedQuery(input.query, fallback: "근로기준법")

        do {
            let results = try await KoreanLawDirectConnector.search(
                KoreanLawSearchRequest(query: query, lawName: nil, article: nil),
                lawOC: lawOC
            )
            if results.isEmpty {
                return .succeeded(MyTeamToolResult(
                    title: "법령 검색 결과가 없습니다",
                    summary: "'\(query)' 기준 공식 법령 검색 결과를 찾지 못했습니다.",
                    sourceLabel: "국가법령정보센터",
                    body: nil,
                    items: [],
                    nextActions: [
                        MyTeamNextAction(id: "changeKeyword", title: "키워드 바꾸기", role: .normal),
                        MyTeamNextAction(id: "checkConnection", title: "연결 확인", role: .normal)
                    ]
                ))
            }

            return .succeeded(MyTeamToolResult(
                title: "공식 법령 검색 결과입니다",
                summary: "법률 자문이 아닌 공식 출처 기반 검색 결과 \(results.count)건입니다. 조문 검증은 별도 확인이 필요합니다.",
                sourceLabel: "국가법령정보센터 · partial",
                body: nil,
                items: results.prefix(5).map { result in
                    MyTeamToolResultItem(
                        id: "\(result.lawName)-\(result.effectiveDate ?? "unknown")",
                        title: result.lawName,
                        subtitle: result.summary,
                        metadata: [
                            result.effectiveDate.map { "시행일 \($0)" },
                            "검증 상태 \(result.verificationStatus)"
                        ].compactMap(\.self).joined(separator: " · "),
                        sourceURL: result.officialSourceURL
                    )
                },
                nextActions: [
                    MyTeamNextAction(id: "searchAgain", title: "다시 검색", role: .normal),
                    MyTeamNextAction(id: "checkConnection", title: "연결 확인", role: .normal)
                ]
            ))
        } catch {
            return failureState(error, provider: provider)
        }
    }

    private func credentialValue(provider: ExternalProvider, fieldID: String) async -> String? {
        await MainActor.run {
            guard
                let field = provider.credentialSchema.fields.first(where: { $0.id == fieldID }),
                let value = SecureCredentialStore.shared.read(provider: provider, field: field)?.trimmingCharacters(in: .whitespacesAndNewlines),
                !value.isEmpty
            else {
                return nil
            }
            return value
        }
    }

    private func sanitizedQuery(_ query: String?, fallback: String) -> String {
        let trimmed = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func localBriefingItems(from snapshot: DailyBriefingLocalSnapshot) -> [MyTeamToolResultItem] {
        let taskItems = snapshot.taskItems.prefix(3).map { item in
            MyTeamToolResultItem(
                id: item.id.uuidString,
                title: item.title,
                subtitle: item.dueText,
                metadata: "우선순위 \(item.priority)",
                sourceURL: nil
            )
        }
        let attentionItems = snapshot.attentionItems.prefix(3).map { item in
            MyTeamToolResultItem(
                id: item.id.uuidString,
                title: item.title,
                subtitle: item.detail,
                metadata: item.severity.rawValue,
                sourceURL: nil
            )
        }
        return Array(taskItems + attentionItems).prefix(5).map { $0 }
    }

    private func localBriefingBody(from snapshot: DailyBriefingLocalSnapshot) -> String {
        var lines: [String] = [
            "# 오늘 브리핑",
            "",
            "## 요약",
            "- \(snapshot.summary)",
            "",
            "## 오늘 할 일"
        ]
        if snapshot.taskItems.isEmpty {
            lines.append("- 현재 로컬 작업에서 바로 표시할 할 일이 없습니다.")
        } else {
            lines.append(contentsOf: snapshot.taskItems.prefix(5).map { item in
                let due = item.dueText.map { " · \($0)" } ?? ""
                return "- \(item.title)\(due)"
            })
        }
        lines.append("")
        lines.append("## 확인 필요")
        if snapshot.attentionItems.isEmpty {
            lines.append("- 현재 확인이 필요한 항목이 없습니다.")
        } else {
            lines.append(contentsOf: snapshot.attentionItems.prefix(5).map { item in
                "- \(item.title): \(item.detail)"
            })
        }
        return lines.joined(separator: "\n")
    }

    private func calendarBody(from items: [DailyCalendarBriefingItem]) -> String {
        var lines = [
            "# 오늘 일정",
            ""
        ]
        lines.append(contentsOf: items.prefix(10).map { item in
            let detail = [item.timeText, item.location].compactMap { $0 }.joined(separator: " · ")
            return detail.isEmpty ? "- \(item.title)" : "- \(item.title) · \(detail)"
        })
        return lines.joined(separator: "\n")
    }

    private func googleSheetsReadRequest(from query: String?) -> GoogleSheetsReadRequest? {
        let raw = (query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let defaultRange = "Sheet1!A1:Z100"

        if let url = URL(string: raw), let host = url.host, host.contains("docs.google.com") {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let range = components?.queryItems?.first(where: { $0.name == "range" })?.value ?? defaultRange
            let parts = url.pathComponents
            if let index = parts.firstIndex(of: "d"), parts.indices.contains(index + 1) {
                return GoogleSheetsReadRequest(
                    spreadsheetID: parts[index + 1],
                    range: sanitizedSheetRange(range, fallback: defaultRange)
                )
            }
        }

        let tokens = raw
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .map(String.init)
        guard let idToken = tokens.first else { return nil }
        let id = spreadsheetID(from: idToken) ?? idToken
        let range = tokens.dropFirst().first.map { String($0) } ?? defaultRange
        guard isLikelySpreadsheetID(id) else { return nil }
        return GoogleSheetsReadRequest(
            spreadsheetID: id,
            range: sanitizedSheetRange(range, fallback: defaultRange)
        )
    }

    private func spreadsheetID(from value: String) -> String? {
        guard let url = URL(string: value), let host = url.host, host.contains("docs.google.com") else {
            return nil
        }
        let parts = url.pathComponents
        guard let index = parts.firstIndex(of: "d"), parts.indices.contains(index + 1) else {
            return nil
        }
        return parts[index + 1]
    }

    private func isLikelySpreadsheetID(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 20 else { return false }
        return trimmed.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
    }

    private func sanitizedSheetRange(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return fallback }
        return trimmed
    }

    private func googleSheetsTableBody(_ result: GoogleSheetsReadResult) -> String {
        let previewRows = result.values.prefix(20)
        let lines = previewRows.map { row in
            row.map { cell in
                cell.replacingOccurrences(of: "\n", with: " ")
            }
            .joined(separator: " | ")
        }
        return ([
            "# Google Sheets 읽기",
            "",
            "- 범위: \(result.range)",
            "- 행: \(result.rowCount)",
            "- 열: \(result.columnCount)",
            "",
            "## 미리보기"
        ] + lines.map { "- \($0)" }).joined(separator: "\n")
    }

    private func googleSheetsFailureState(_ error: Error) -> ToolExecutionState {
        let title: String
        let message: String
        let actions: [MyTeamNextAction]

        switch error {
        case GoogleSheetsClientError.missingToken:
            title = "Google Sheets 연결이 필요합니다"
            message = "Google Sheets 읽기 연결을 먼저 완료하세요."
            actions = [MyTeamNextAction(id: "openAssistantConnection", title: "비서 연결", role: .normal)]
        case GoogleSheetsClientError.needsReauth, GoogleSheetsClientError.unauthorized:
            title = "Google Sheets 재인증이 필요합니다"
            message = "Google 로그인 토큰이 만료되었거나 사용할 수 없습니다."
            actions = [MyTeamNextAction(id: "openAssistantConnection", title: "비서 연결", role: .normal)]
        case GoogleSheetsClientError.unsupportedScope:
            title = "Google Sheets 읽기 권한이 필요합니다"
            message = "현재 토큰에 spreadsheets.readonly 권한이 없습니다. Google Sheets 읽기 연결을 다시 진행해 주세요."
            actions = [MyTeamNextAction(id: "openAssistantConnection", title: "비서 연결", role: .normal)]
        case GoogleSheetsClientError.forbidden:
            title = "시트 접근 권한이 없습니다"
            message = "해당 스프레드시트를 볼 수 있는 Google 계정으로 연결했는지 확인하세요."
            actions = [MyTeamNextAction(id: "openAssistantConnection", title: "비서 연결", role: .normal)]
        case GoogleSheetsClientError.notFound:
            title = "스프레드시트를 찾지 못했습니다"
            message = "spreadsheetId 또는 URL이 올바른지 확인하세요."
            actions = [MyTeamNextAction(id: "changeKeyword", title: "다시 입력", role: .normal)]
        case GoogleSheetsClientError.invalidRequest:
            title = "시트 범위를 확인하세요"
            message = "예: Sheet1!A1:Z100 형식의 범위를 입력해 주세요."
            actions = [MyTeamNextAction(id: "changeKeyword", title: "범위 바꾸기", role: .normal)]
        case GoogleSheetsClientError.decodeFailed:
            title = "시트 응답을 해석하지 못했습니다"
            message = "Google Sheets 응답 형식이 예상과 다릅니다."
            actions = [MyTeamNextAction(id: "searchAgain", title: "다시 시도", role: .normal)]
        default:
            title = "Google Sheets 값을 가져오지 못했습니다"
            message = "네트워크 상태 또는 Google Sheets API 설정을 확인하세요."
            actions = [MyTeamNextAction(id: "searchAgain", title: "다시 시도", role: .normal)]
        }

        return .failed(MyTeamToolFailure(
            title: title,
            message: message,
            recoveryActions: actions
        ))
    }

    private func calendarFailureState(fetchStatus: String, message: String) -> ToolExecutionState {
        let actions: [MyTeamNextAction]
        switch fetchStatus {
        case "missing_token", "needs_reauth", "forbidden":
            actions = [
                MyTeamNextAction(id: "openAssistantConnection", title: "비서 연결", role: .normal)
            ]
        default:
            actions = [
                MyTeamNextAction(id: "searchAgain", title: "다시 시도", role: .normal)
            ]
        }
        let title: String
        switch fetchStatus {
        case "missing_token":
            title = "Google Calendar 연결이 필요합니다"
        case "needs_reauth":
            title = "Google Calendar 재인증이 필요합니다"
        case "forbidden":
            title = "Google Calendar 읽기 권한이 필요합니다"
        default:
            title = "Google Calendar 일정을 가져오지 못했습니다"
        }
        return .failed(MyTeamToolFailure(
            title: title,
            message: message,
            recoveryActions: actions
        ))
    }

    private func estimatedColumnCount(_ row: String) -> Int {
        let separators: [Character] = ["\t", ",", "|"]
        return separators
            .map { separator in row.split(separator: separator, omittingEmptySubsequences: false).count }
            .max() ?? 0
    }

    private func spreadsheetPostprocessBody(source: String, rowCount: Int, columnGuess: Int) -> String {
        """
        # 엑셀 후처리 계획

        ## 1. 입력 진단
        - 감지한 행: \(rowCount)개
        - 추정 열: \(columnGuess > 0 ? "\(columnGuess)개" : "미확인")
        - 현재 단계에서는 파일 저장 성공을 주장하지 않고, 정리 계획과 검산 기준만 생성합니다.

        ## 2. 정리 순서
        - 헤더 행을 하나로 확정합니다.
        - 빈 행과 합계 행을 분리합니다.
        - 날짜, 금액, 수량, 비율 열의 형식을 통일합니다.
        - 중복 키와 누락 값을 표시합니다.

        ## 3. 검산 기준
        - 원본 행 수와 정리 후 행 수를 비교합니다.
        - 금액 합계가 바뀌었는지 확인합니다.
        - 필수 열이 비어 있는 행을 따로 모읍니다.

        ## 4. 보고용 변환
        - 요약 표, 이상치 표, 확인 필요 표로 나눕니다.
        - 숫자 근거가 없는 결론은 작성하지 않습니다.

        ## 참고 입력
        \(source)
        """
    }

    private func weatherSummaryParts(from observations: [KMAWeatherDirectObservation]) -> [String] {
        observations.compactMap { observation in
            switch observation.category {
            case "T1H":
                return "기온 \(observation.value)℃"
            case "RN1":
                return "1시간 강수량 \(observation.value)mm"
            case "REH":
                return "습도 \(observation.value)%"
            case "WSD":
                return "풍속 \(observation.value)m/s"
            default:
                return nil
            }
        }
    }

    private func weatherTitle(for category: String) -> String {
        switch category {
        case "T1H": return "기온"
        case "RN1": return "1시간 강수량"
        case "UUU": return "동서바람성분"
        case "VVV": return "남북바람성분"
        case "REH": return "습도"
        case "PTY": return "강수형태"
        case "VEC": return "풍향"
        case "WSD": return "풍속"
        default: return category
        }
    }

    private func weatherUnit(for category: String) -> String {
        switch category {
        case "T1H": return "℃"
        case "RN1": return "mm"
        case "REH": return "%"
        case "WSD", "UUU", "VVV": return "m/s"
        case "VEC": return "°"
        default: return ""
        }
    }

    private func kmaOfficialURL() -> URL? {
        URL(string: "https://www.data.go.kr/tcs/dss/selectApiDataDetailView.do?publicDataPk=15084084")
    }

    private func failureState(_ error: Error, provider: ExternalProvider) -> ToolExecutionState {
        let code = error as? ConnectorFailureCode ?? .networkError
        return .failed(MyTeamToolFailure(
            title: "확인이 필요합니다",
            message: code.userMessage(for: provider),
            recoveryActions: recoveryActions(for: code)
        ))
    }

    private func recoveryActions(for code: ConnectorFailureCode) -> [MyTeamNextAction] {
        switch code {
        case .missingAPIKey, .invalidAPIKey, .permissionDenied:
            return [
                MyTeamNextAction(id: "openConnection", title: "키 확인", role: .normal),
                MyTeamNextAction(id: "retry", title: "다시 시도", role: .normal)
            ]
        case .rateLimited, .quotaExceeded, .providerUnavailable:
            return [MyTeamNextAction(id: "retryLater", title: "잠시 후 재시도", role: .normal)]
        case .networkError:
            return [MyTeamNextAction(id: "checkNetwork", title: "네트워크 확인", role: .normal)]
        case .responseParseFailed, .unsupportedRegion, .releaseProfileBlocked:
            return [MyTeamNextAction(id: "retry", title: "다시 시도", role: .normal)]
        }
    }

    private static func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func distributionMessage(for descriptor: MyTeamToolDescriptor) -> String {
        switch FeatureGate.current {
        case .appStore:
            return "\(descriptor.displayName)은 App Store 프로필에서 비활성입니다."
        case .direct:
            return "\(descriptor.displayName)은 Direct 프로필에서 사용할 수 없습니다."
        case .developer:
            return "\(descriptor.displayName)은 현재 개발자 프로필에서 사용할 수 없습니다."
        }
    }
}

private struct GoogleSheetsReadRequest: Sendable, Equatable {
    let spreadsheetID: String
    let range: String
}
