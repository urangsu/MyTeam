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
        case "dart.disclosures.search":
            return await runDART(input: input)
        case "news.search":
            return await runNaverNews(input: input)
        default:
            return .unavailable("이 업무는 아직 실행 연결 전입니다.")
        }
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
