import Foundation

private final class ToolExecutionRaceBox: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var didResolve = false
    nonisolated(unsafe) private var operationTask: Task<Void, Never>?
    nonisolated(unsafe) private var timeoutTask: Task<Void, Never>?

    nonisolated init() {}

    nonisolated func setTasks(operation: Task<Void, Never>, timeout: Task<Void, Never>) {
        lock.lock()
        if didResolve {
            lock.unlock()
            operation.cancel()
            timeout.cancel()
            return
        }
        operationTask = operation
        timeoutTask = timeout
        lock.unlock()
    }

    nonisolated func resolve(
        _ state: ToolExecutionState,
        continuation: CheckedContinuation<ToolExecutionState, Never>
    ) {
        lock.lock()
        guard !didResolve else {
            lock.unlock()
            return
        }
        didResolve = true
        let operationTask = operationTask
        let timeoutTask = timeoutTask
        lock.unlock()

        operationTask?.cancel()
        timeoutTask?.cancel()
        continuation.resume(returning: state)
    }
}

private enum ToolExecutionDispatcher {
    static func run(
        descriptor: MyTeamToolDescriptor,
        input: MyTeamToolInput,
        router: ToolExecutionRouter
    ) async -> ToolExecutionState {
        switch descriptor.id {
        case "briefing.today":
            return await router.runTodayBriefing()
        case "document.meetingMinutes":
            return await router.runUniversalDocument(type: .meetingMinutes, input: input)
        case "document.rewrite":
            return await router.runUniversalDocument(type: .summary, input: input)
        case "spreadsheet.postprocess":
            return await router.runSpreadsheetPostprocess(input: input)
        case "spreadsheet.googleSheets.read":
            return await router.runWithHardTimeout(descriptor) { await router.runGoogleSheetsRead(input: input) }
        case "calendar.events.today":
            return await router.runWithHardTimeout(descriptor) { await router.runGoogleCalendarToday() }
        case "dart.disclosures.search":
            return await router.runWithHardTimeout(descriptor) { await DARTToolRunner.run(input: input) }
        case "news.search":
            return await router.runWithHardTimeout(descriptor) { await NewsToolRunner.run(input: input) }
        case "weather.current":
            return await router.runWithHardTimeout(descriptor) { await WeatherToolRunner.run(input: input) }
        case "finance.krx.stockPrice":
            return await router.runWithHardTimeout(descriptor) { await FinanceToolRunner.runStockPrice(input: input) }
        case "finance.krx.index":
            return await router.runWithHardTimeout(descriptor) { await FinanceToolRunner.runMarketIndex(input: input) }
        case "finance.company.statement":
            return await router.runWithHardTimeout(descriptor) { await FinanceToolRunner.runCompanyStatement(input: input) }
        case "law.search":
            return await router.runWithHardTimeout(descriptor) { await LawToolRunner.run(input: input) }
        default:
            return .unavailable("이 업무는 아직 실행 연결 전입니다.")
        }
    }
}

actor ToolExecutionRouter {
    static let shared = ToolExecutionRouter()
    private let externalReadHardTimeoutNanoseconds: UInt64 = 10_000_000_000

    func readiness(for descriptor: MyTeamToolDescriptor) async -> ToolExecutionState {
        guard FeatureGate.allows(descriptor) else {
            return .unavailable(distributionMessage(for: descriptor))
        }

        guard descriptor.isImplemented else {
            return .unavailable("이 기능은 준비 중입니다.")
        }

        if let requirement = descriptor.requiredCredential {
            switch requirement.provider {
            case .external(let provider):
                let health = await MainActor.run {
                    CredentialHealthService.shared.health(for: provider)
                }
                switch health.state {
                case .notConnected:
                    return .needsConnection(provider)
                case .untested, .testUnavailable:
                    return .needsValidation(provider)
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
            case .assistant(let provider):
                let connectionState = await MainActor.run {
                    AssistantConnectorCatalog.connectionState(for: provider)
                }
                switch connectionState.status {
                case .connected:
                    break
                case .notConfigured, .notConnected, .needsReauth:
                    return .needsAssistantConnection(provider)
                case .comingSoon:
                    return .unavailable("\(provider.displayName) 연결은 준비 중입니다.")
                case .error:
                    return .failed(MyTeamToolFailure(
                        title: "\(provider.displayName) 연결 상태를 확인하세요",
                        message: connectionState.message,
                        recoveryActions: [
                            MyTeamNextAction(id: "openAssistantConnection", title: "비서 연결", role: .normal)
                        ]
                    ))
                }
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

    func run(
        _ descriptor: MyTeamToolDescriptor,
        input: MyTeamToolInput,
        bypassApproval: Bool,
        path: ToolExecutionPath = .toolCard,
        options: ToolExecutionOptions = .standalone
    ) async -> ToolExecutionState {
        let logID = await MainActor.run {
            ToolExecutionLogStore.shared.start(descriptor: descriptor, path: path)
        }
        let state = await readiness(for: descriptor, bypassApproval: bypassApproval)
        guard state.isRunnable else {
            await finishLog(id: logID, state: state)
            return state
        }

        let result = await ToolExecutionDispatcher.run(
            descriptor: descriptor,
            input: input,
            router: self
        )
        let artifact = options.persistIndividualArtifact
            ? await persistArtifactIfPossible(descriptor: descriptor, result: result, input: input)
            : nil
        await finishLog(id: logID, state: result, artifact: artifact)
        return result
    }

    private func readiness(for descriptor: MyTeamToolDescriptor, bypassApproval: Bool) async -> ToolExecutionState {
        let state = await readiness(for: descriptor)
        guard case .needsApproval = state, bypassApproval else { return state }
        return .idle
    }

    private func finishLog(id: UUID, state: ToolExecutionState, artifact: IndexedArtifact? = nil) async {
        await MainActor.run {
            ToolExecutionLogStore.shared.finish(id: id, state: state, artifact: artifact)
        }
    }

    private func persistArtifactIfPossible(
        descriptor: MyTeamToolDescriptor,
        result state: ToolExecutionState,
        input: MyTeamToolInput
    ) async -> IndexedArtifact? {
        guard case .succeeded(let result) = state else { return nil }
        guard descriptor.category != .voice, descriptor.category != .system else { return nil }
        return await ToolResultArtifactWriter.write(
            descriptor: descriptor,
            result: result,
            input: input
        )
    }

    fileprivate func runWithHardTimeout(
        _ descriptor: MyTeamToolDescriptor,
        operation: @escaping @Sendable () async -> ToolExecutionState
    ) async -> ToolExecutionState {
        let timeoutState = ToolExecutionState.failed(MyTeamToolFailure(
            title: "\(descriptor.displayName) 시간 초과",
            message: "10초 안에 결과를 받지 못했습니다. 연결 상태를 확인하거나 잠시 후 다시 시도하세요.",
            recoveryActions: [
                MyTeamNextAction(id: "retryLater", title: "다시 시도", role: .normal)
            ]
        ))

        return await withCheckedContinuation { continuation in
            let box = ToolExecutionRaceBox()
            let operationTask = Task(priority: .userInitiated) {
                let state = await operation()
                box.resolve(state, continuation: continuation)
            }
            let timeoutTask = Task(priority: .userInitiated) { [externalReadHardTimeoutNanoseconds] in
                try? await Task.sleep(nanoseconds: externalReadHardTimeoutNanoseconds)
                guard !Task.isCancelled else { return }
                box.resolve(timeoutState, continuation: continuation)
            }
            box.setTasks(operation: operationTask, timeout: timeoutTask)
        }
    }

    fileprivate func runTodayBriefing() async -> ToolExecutionState {
        let snapshot = await MainActor.run {
            DailyBriefingLocalProvider.makeSnapshot(
                roomID: AgentWindowManager.shared.currentRoomID,
                manager: .shared
            )
        }
        let body = LocalBriefingResultFormatter.body(from: snapshot)
        return .succeeded(MyTeamToolResult(
            title: "오늘 로컬 업무 브리핑을 준비했습니다",
            summary: snapshot.summary,
            sourceLabel: "로컬 작업 상태",
            body: body,
            items: LocalBriefingResultFormatter.items(from: snapshot),
            nextActions: [
                MyTeamNextAction(id: "searchAgain", title: "새로고침", role: .normal)
            ]
        ))
    }

    fileprivate func runUniversalDocument(type: UniversalDocumentSkillType, input: MyTeamToolInput) async -> ToolExecutionState {
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

    fileprivate func runSpreadsheetPostprocess(input: MyTeamToolInput) -> ToolExecutionState {
        let source = sanitizedQuery(input.query, fallback: "표 내용을 붙여넣으면 정리 계획을 만듭니다.")
        let rows = source
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let columnGuess = rows.map(SpreadsheetPlanResultFormatter.estimatedColumnCount).max() ?? 0
        let body = SpreadsheetPlanResultFormatter.body(source: source, rowCount: rows.count, columnGuess: columnGuess)
        return .succeeded(MyTeamToolResult(
            title: "표 정리 계획을 만들었습니다",
            summary: "붙여넣은 표/메모를 기준으로 정리, 검산, 보고용 변환 단계를 제안했습니다. 실제 Excel 파일은 편집하지 않았습니다.",
            sourceLabel: "MyTeam 로컬 표 정리 런타임",
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

    fileprivate func runGoogleSheetsRead(input: MyTeamToolInput) async -> ToolExecutionState {
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
                message: "입력 예: https://docs.google.com/spreadsheets/d/.../edit 또는 spreadsheetId Sheet1!A1:Z100",
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
                body: GoogleSheetsResultFormatter.tableBody(result),
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

    fileprivate func runGoogleCalendarToday() async -> ToolExecutionState {
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
        if items.isEmpty, calendarStatus.fetchStatus != .empty {
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
            body: CalendarResultFormatter.body(from: items),
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

    private func sanitizedQuery(_ query: String?, fallback: String) -> String {
        let trimmed = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
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
            message = "spreadsheetId 또는 URL이 올바른지 확인하세요. 예: spreadsheetId Sheet1!A1:Z100"
            actions = [MyTeamNextAction(id: "changeKeyword", title: "다시 입력", role: .normal)]
        case GoogleSheetsClientError.invalidRequest:
            title = "시트 범위를 확인하세요"
            message = "예: spreadsheetId Sheet1!A1:Z100 형식으로 입력해 주세요."
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

    private func calendarFailureState(fetchStatus: GoogleCalendarFetchStatus, message: String) -> ToolExecutionState {
        let actions: [MyTeamNextAction]
        switch fetchStatus {
        case .missingToken, .needsReauth, .forbidden:
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
        case .missingToken:
            title = "Google Calendar 연결이 필요합니다"
        case .needsReauth:
            title = "Google Calendar 재인증이 필요합니다"
        case .forbidden:
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
