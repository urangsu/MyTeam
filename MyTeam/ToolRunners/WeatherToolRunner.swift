import Foundation

enum WeatherToolRunner {
    static func run(input: MyTeamToolInput) async -> ToolExecutionState {
        let provider = ExternalProvider.kmaWeather
        guard let query = requiredQuery(input.query) else {
            return .failed(MyTeamToolFailure(
                title: "날씨 지역이 필요합니다",
                message: "날씨를 확인할 지역명을 입력해 주세요. 예: 광양, 포항, 서울.",
                recoveryActions: [
                    MyTeamNextAction(id: "changeKeyword", title: "지역 입력", role: .normal)
                ]
            ))
        }
        guard let region = KMARegionGridMapper.resolve(query) else {
            return .failed(MyTeamToolFailure(
                title: "지역 격자를 찾지 못했습니다",
                message: KMARegionGridMapper.userFacingUnsupportedMessage(for: query),
                recoveryActions: [
                    MyTeamNextAction(id: "changeKeyword", title: "지역 바꾸기", role: .normal)
                ]
            ))
        }
        let nx = input.nx ?? region.nx
        let ny = input.ny ?? region.ny

        do {
            let response = try await MyTeamBasicLookupProxyClient.shared.fetchKMANowcast(
                nx: nx,
                ny: ny
            )
            return WeatherResultFormatter.resultState(
                regionName: region.name,
                nx: nx,
                ny: ny,
                observations: response.directObservations,
                sourceLabel: "MyTeam 기본 기상청 조회",
                modeNotice: "기상청 단기예보 조회 결과입니다. 위치 좌표 기준의 공식 기상 데이터입니다."
            )
        } catch MyTeamProxyError.noResults {
            return WeatherResultFormatter.resultState(
                regionName: region.name,
                nx: nx,
                ny: ny,
                observations: [],
                sourceLabel: "MyTeam 기본 기상청 조회",
                modeNotice: "기상청 단기예보 조회 결과입니다. 위치 좌표 기준의 공식 기상 데이터입니다."
            )
        } catch let proxyError as MyTeamProxyError {
            return await directFallbackState(
                provider: provider,
                region: region,
                nx: nx,
                ny: ny,
                missingKeyMessage: weatherMissingKeyMessage(proxyError.errorDescription)
            )
        } catch {
            return await directFallbackState(
                provider: provider,
                region: region,
                nx: nx,
                ny: ny,
                missingKeyMessage: "기본 조회 서버가 응답하지 않습니다. 잠시 후 다시 시도하거나 개인 기상청 Service Key를 연결하세요."
            )
        }
    }

    private static func directFallbackState(
        provider: ExternalProvider,
        region: KMAGridRegion,
        nx: Int,
        ny: Int,
        missingKeyMessage: String
    ) async -> ToolExecutionState {
        guard let serviceKey = credentialValue(provider: provider, fieldID: "serviceKey") else {
            return .failed(MyTeamToolFailure(
                title: "날씨 조회를 완료하지 못했습니다",
                message: missingKeyMessage,
                recoveryActions: [
                    MyTeamNextAction(id: "retryLater", title: "다시 시도", role: .normal),
                    MyTeamNextAction(id: "openConnection", title: "개인 키 연결", role: .normal)
                ]
            ))
        }
        do {
            let observations = try await KMAWeatherDirectConnector.ultraShortNowcast(
                serviceKey: serviceKey,
                nx: nx,
                ny: ny
            )
            return WeatherResultFormatter.resultState(
                regionName: region.name,
                nx: nx,
                ny: ny,
                observations: observations,
                sourceLabel: "기상청 초단기실황 · 개인 키",
                modeNotice: "기본 조회 서버가 응답하지 않아 개인 기상청 Service Key로 조회했습니다. 위치 좌표 기준의 공식 기상 데이터입니다."
            )
        } catch {
            return .failed(MyTeamToolFailure(
                title: "날씨 조회를 완료하지 못했습니다",
                message: "기본 조회 서버와 개인 기상청 Service Key 조회가 모두 실패했습니다. 잠시 후 다시 시도하거나 개인 키 권한을 확인하세요.",
                recoveryActions: [
                    MyTeamNextAction(id: "retryLater", title: "다시 시도", role: .normal),
                    MyTeamNextAction(id: "openConnection", title: "개인 키 확인", role: .normal)
                ]
            ))
        }
    }

    private static func weatherMissingKeyMessage(_ proxyMessage: String?) -> String {
        if let proxyMessage, proxyMessage.contains("기상청 조회 인증 설정") {
            return "기상청 조회 인증 설정을 확인해야 합니다. 관리자 기본 조회 키 또는 개인 API 키 설정을 확인하세요."
        }
        return proxyMessage ?? "기본 조회 서버가 응답하지 않습니다. 잠시 후 다시 시도하거나 개인 기상청 Service Key를 연결하세요."
    }

    private static func requiredQuery(_ query: String?) -> String? {
        let trimmed = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    @MainActor
    private static func credentialValue(provider: ExternalProvider, fieldID: String) -> String? {
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
