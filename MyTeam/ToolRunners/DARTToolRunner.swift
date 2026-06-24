import Foundation

enum DARTToolRunner {
    static func run(input: MyTeamToolInput) async -> ToolExecutionState {
        let provider = ExternalProvider.dartDisclosure
        guard let query = PublicLookupRunnerSupport.requiredQuery(input.query) else {
            return .failed(MyTeamToolFailure(
                title: "공시 조회 입력이 필요합니다",
                message: "조회할 회사명, 6자리 종목코드, 또는 OpenDART 고유번호를 입력해 주세요. 예: 삼성전자, 005930, 00126380.",
                recoveryActions: [
                    MyTeamNextAction(id: "changeKeyword", title: "회사 입력", role: .normal)
                ]
            ))
        }
        let resolution = DARTCompanyResolver.resolve(input: query)
        let daysBack = min(max(input.daysBack ?? 30, 1), 365)
        let displayCount = min(max(input.displayCount ?? 10, 1), 20)

        guard let corpCode = resolution.corpCode else {
            return .failed(MyTeamToolFailure(
                title: "회사를 찾지 못했습니다",
                message: "종목코드 또는 OpenDART 고유번호를 입력해 주세요. 예: 삼성전자, 005930, 00126380.",
                recoveryActions: [
                    MyTeamNextAction(id: "changeKeyword", title: "다시 입력", role: .normal)
                ]
            ))
        }

        guard let apiKey = PublicLookupRunnerSupport.credentialValue(provider: provider, fieldID: "apiKey") else {
            return .failed(MyTeamToolFailure(
                title: "DART 개인 API 키 연결이 필요합니다",
                message: "DART 공시 조회에는 개인 OpenDART API 키가 필요합니다. 연결 설정에서 DART 키를 등록한 뒤 다시 시도하세요.",
                recoveryActions: [
                    MyTeamNextAction(id: "openConnection", title: "DART 키 연결", role: .normal)
                ]
            ))
        }

        do {
            let items = try await DARTDisclosureDirectConnector.recentDisclosures(
                corpCode: corpCode,
                apiKey: apiKey,
                daysBack: daysBack,
                pageCount: displayCount
            )
            return DARTResultFormatter.resultState(
                resolution: resolution,
                daysBack: daysBack,
                items: items,
                sourceLabel: "DART 공시 · 개인 키",
                modeNotice: "DART 공시 목록을 가져왔습니다. 공시 원문은 DART 공식 링크에서 확인하세요."
            )
        } catch {
            return directFailureState(error)
        }
    }

    private static func directFailureState(_ error: Error) -> ToolExecutionState {
        let failureCode = error as? ConnectorFailureCode
        let message: String
        let actions: [MyTeamNextAction]

        if error is URLError {
            message = "OpenDART 보안 연결 또는 네트워크 연결을 만들지 못했습니다. 앱을 다시 실행한 뒤 재시도하세요."
            actions = [
                MyTeamNextAction(id: "retryLater", title: "다시 시도", role: .normal)
            ]
        } else {
            switch failureCode {
            case .invalidAPIKey?:
                message = "DART API 키가 유효하지 않습니다. OpenDART 인증키 상태를 확인하세요."
                actions = [
                    MyTeamNextAction(id: "openConnection", title: "DART 키 확인", role: .normal)
                ]
            case .permissionDenied?:
                message = "DART API 키 권한 또는 접근 허용 상태를 확인하세요."
                actions = [
                    MyTeamNextAction(id: "openConnection", title: "DART 키 확인", role: .normal)
                ]
            case .quotaExceeded?, .rateLimited?:
                message = "OpenDART 요청 한도에 도달했습니다. 잠시 후 다시 시도하세요."
                actions = [
                    MyTeamNextAction(id: "retryLater", title: "다시 시도", role: .normal)
                ]
            case .providerUnavailable?, .networkError?:
                message = "OpenDART 제공기관 응답 지연으로 공시 조회를 완료하지 못했습니다. 잠시 후 다시 시도하세요."
                actions = [
                    MyTeamNextAction(id: "retryLater", title: "다시 시도", role: .normal)
                ]
            default:
                message = "DART 응답을 해석하지 못했습니다. 고유번호와 OpenDART 인증키 상태를 확인하세요."
                actions = [
                    MyTeamNextAction(id: "openConnection", title: "DART 키 확인", role: .normal),
                    MyTeamNextAction(id: "changeKeyword", title: "고유번호 확인", role: .normal)
                ]
            }
        }

        return .failed(MyTeamToolFailure(
            title: "공시 조회를 완료하지 못했습니다",
            message: message,
            recoveryActions: actions
        ))
    }
}
