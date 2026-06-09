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
        let state = await readiness(for: descriptor)
        guard state.isRunnable else { return state }

        switch descriptor.id {
        case "briefing.today":
            return await runTodayBriefing()
        case "document.meetingMinutes":
            return await runUniversalDocument(type: .meetingMinutes, input: input)
        case "document.rewrite":
            return await runUniversalDocument(type: .summary, input: input)
        case "spreadsheet.postprocess":
            return runSpreadsheetPostprocess(input: input)
        case "calendar.events.today":
            return await runGoogleCalendarToday()
        case "dart.disclosures.search":
            return await runDART(input: input)
        case "news.search":
            return await runNaverNews(input: input)
        case "weather.current":
            return await runKMAWeather(input: input)
        case "law.search":
            return await runKoreanLaw(input: input)
        default:
            return .unavailable("이 업무는 아직 실행 연결 전입니다.")
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
        let status = await MainActor.run {
            GoogleDailyBriefingCalendarProvider.shared.statusMessage
        }
        if items.isEmpty {
            return .succeeded(MyTeamToolResult(
                title: "오늘 일정이 없습니다",
                summary: status,
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
            summary: status,
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
        let region = kmaRegion(from: input.query)
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

    private func kmaRegion(from query: String?) -> KMAGridRegion {
        let raw = (query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return KMAGridRegion.default }
        let normalized = raw
            .replacingOccurrences(of: "특별시", with: "")
            .replacingOccurrences(of: "광역시", with: "")
            .replacingOccurrences(of: "특별자치시", with: "")
            .replacingOccurrences(of: "특별자치도", with: "")
            .replacingOccurrences(of: "시", with: "")
            .replacingOccurrences(of: "군", with: "")
            .replacingOccurrences(of: "구", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return KMAGridRegion.known.first { region in
            raw.contains(region.name) || normalized.contains(region.name) || region.aliases.contains { raw.contains($0) || normalized.contains($0) }
        } ?? .default
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

private struct KMAGridRegion: Sendable, Equatable {
    let name: String
    let nx: Int
    let ny: Int
    let aliases: [String]

    nonisolated static let `default` = KMAGridRegion(name: "서울", nx: 60, ny: 127, aliases: ["서울"])

    nonisolated static let known: [KMAGridRegion] = [
        KMAGridRegion(name: "서울", nx: 60, ny: 127, aliases: ["서울특별시", "강남", "서초", "송파", "마포", "종로"]),
        KMAGridRegion(name: "부산", nx: 98, ny: 76, aliases: ["부산광역시", "해운대", "서면"]),
        KMAGridRegion(name: "대구", nx: 89, ny: 90, aliases: ["대구광역시"]),
        KMAGridRegion(name: "인천", nx: 55, ny: 124, aliases: ["인천광역시"]),
        KMAGridRegion(name: "광주", nx: 58, ny: 74, aliases: ["광주광역시"]),
        KMAGridRegion(name: "대전", nx: 67, ny: 100, aliases: ["대전광역시"]),
        KMAGridRegion(name: "울산", nx: 102, ny: 84, aliases: ["울산광역시"]),
        KMAGridRegion(name: "세종", nx: 66, ny: 103, aliases: ["세종특별자치시"]),
        KMAGridRegion(name: "수원", nx: 60, ny: 121, aliases: ["경기 수원", "수원시"]),
        KMAGridRegion(name: "성남", nx: 62, ny: 123, aliases: ["분당", "판교", "성남시"]),
        KMAGridRegion(name: "용인", nx: 64, ny: 119, aliases: ["용인시"]),
        KMAGridRegion(name: "고양", nx: 57, ny: 128, aliases: ["고양시", "일산"]),
        KMAGridRegion(name: "춘천", nx: 73, ny: 134, aliases: ["춘천시"]),
        KMAGridRegion(name: "강릉", nx: 92, ny: 131, aliases: ["강릉시"]),
        KMAGridRegion(name: "청주", nx: 69, ny: 107, aliases: ["청주시"]),
        KMAGridRegion(name: "천안", nx: 63, ny: 110, aliases: ["천안시"]),
        KMAGridRegion(name: "전주", nx: 63, ny: 89, aliases: ["전주시"]),
        KMAGridRegion(name: "목포", nx: 50, ny: 67, aliases: ["목포시"]),
        KMAGridRegion(name: "여수", nx: 73, ny: 66, aliases: ["여수시"]),
        KMAGridRegion(name: "포항", nx: 102, ny: 94, aliases: ["포항시"]),
        KMAGridRegion(name: "창원", nx: 90, ny: 77, aliases: ["창원시", "마산", "진해"]),
        KMAGridRegion(name: "진주", nx: 81, ny: 75, aliases: ["진주시"]),
        KMAGridRegion(name: "제주", nx: 52, ny: 38, aliases: ["제주시", "제주도"]),
        KMAGridRegion(name: "서귀포", nx: 52, ny: 33, aliases: ["서귀포시"])
    ]
}
