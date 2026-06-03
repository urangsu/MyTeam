import Foundation

// MARK: - ProviderCredentialSchema

struct ProviderCredentialSchema: Equatable, Sendable {
    let fields: [CredentialField]

    var primaryField: CredentialField? {
        fields.first
    }
}

struct CredentialField: Equatable, Sendable, Identifiable {
    let id: String
    let label: String
    let placeholder: String
    let keychainSuffix: String
    let isSecret: Bool
}

enum ConnectorExecutionMode: String, Sendable {
    case byokDirect
    case proxyPlanned
}

// MARK: - ExternalProvider

/// MyTeam이 연결할 수 있는 외부 서비스 provider 목록.
enum ExternalProvider: String, Codable, CaseIterable, Sendable {
    // AI 모델
    case openAI        = "openAI"
    case gemini        = "gemini"
    case anthropic     = "anthropic"
    case openRouter    = "openRouter"

    // 한국 생활/업무
    case kmaWeather    = "kmaWeather"
    case naverNews     = "naverNews"
    case dartDisclosure = "dartDisclosure"
    case koreanLaw     = "koreanLaw"

    var displayName: String {
        switch self {
        case .openAI:         return "OpenAI"
        case .gemini:         return "Google Gemini"
        case .anthropic:      return "Anthropic Claude"
        case .openRouter:     return "OpenRouter"
        case .kmaWeather:     return "기상청 날씨"
        case .naverNews:      return "네이버 뉴스"
        case .dartDisclosure: return "DART 공시"
        case .koreanLaw:      return "한국 법령"
        }
    }

    var description: String {
        switch self {
        case .openAI:
            return "GPT 모델로 AI 대화, 문서 작성, 분석을 할 수 있습니다."
        case .gemini:
            return "Google Gemini 모델로 AI 대화와 멀티모달 분석을 할 수 있습니다."
        case .anthropic:
            return "Claude 모델로 긴 문서 분석과 AI 대화를 할 수 있습니다."
        case .openRouter:
            return "여러 AI 모델을 하나의 키로 연결할 수 있습니다."
        case .kmaWeather:
            return "내일 비, 우산 여부, 세차 타이밍, 출장 날씨 판단에 사용합니다."
        case .naverNews:
            return "국내 최신 뉴스를 검색하고 요약할 수 있습니다."
        case .dartDisclosure:
            return "기업 공시를 실시간으로 확인하고 분석할 수 있습니다."
        case .koreanLaw:
            return "공식 법령 API로 법령 검색, 조문 조회, 인용 검증을 준비합니다."
        }
    }

    var credentialSchema: ProviderCredentialSchema {
        switch self {
        case .naverNews:
            return ProviderCredentialSchema(fields: [
                CredentialField(
                    id: "clientID",
                    label: "Client ID",
                    placeholder: "네이버 개발자 센터 Client ID",
                    keychainSuffix: "clientID",
                    isSecret: false
                ),
                CredentialField(
                    id: "clientSecret",
                    label: "Client Secret",
                    placeholder: "네이버 개발자 센터 Client Secret",
                    keychainSuffix: "clientSecret",
                    isSecret: true
                )
            ])
        case .dartDisclosure:
            return ProviderCredentialSchema(fields: [
                CredentialField(
                    id: "apiKey",
                    label: "API Key",
                    placeholder: "OpenDART API Key",
                    keychainSuffix: "apiKey",
                    isSecret: true
                )
            ])
        case .kmaWeather:
            return ProviderCredentialSchema(fields: [
                CredentialField(
                    id: "serviceKey",
                    label: "Service Key",
                    placeholder: "공공데이터포털 Service Key",
                    keychainSuffix: "serviceKey",
                    isSecret: true
                )
            ])
        case .koreanLaw:
            return ProviderCredentialSchema(fields: [
                CredentialField(
                    id: "lawOC",
                    label: "LAW OC",
                    placeholder: "국가법령정보센터 OC",
                    keychainSuffix: "lawOC",
                    isSecret: true
                )
            ])
        case .openAI, .gemini, .anthropic, .openRouter:
            return ProviderCredentialSchema(fields: [
                CredentialField(
                    id: "apiKey",
                    label: "API Key",
                    placeholder: "API Key",
                    keychainSuffix: "apiKey",
                    isSecret: true
                )
            ])
        }
    }

    var executionModes: [ConnectorExecutionMode] {
        switch self {
        case .kmaWeather, .naverNews, .dartDisclosure, .koreanLaw:
            return [.byokDirect, .proxyPlanned]
        case .openAI, .gemini, .anthropic, .openRouter:
            return [.byokDirect]
        }
    }

    var keyIssueURL: URL? {
        switch self {
        case .openAI:
            return URL(string: "https://platform.openai.com/api-keys")
        case .gemini:
            return URL(string: "https://aistudio.google.com/app/apikey")
        case .anthropic:
            return URL(string: "https://console.anthropic.com/settings/keys")
        case .openRouter:
            return URL(string: "https://openrouter.ai/settings/keys")
        case .kmaWeather:
            return URL(string: "https://www.data.go.kr/tcs/dss/selectApiDataDetailView.do?publicDataPk=15084084")
        case .naverNews:
            return URL(string: "https://developers.naver.com/apps/#/register")
        case .dartDisclosure:
            return URL(string: "https://opendart.fss.or.kr/uat/uia/egovLoginUsr.do")
        case .koreanLaw:
            return URL(string: "https://www.law.go.kr/LSO/openApi/guide.do")
        }
    }

    /// Keychain 저장 키 이름
    var keychainKey: String {
        switch self {
        case .openAI:         return "openAIAPIKey"
        case .gemini:         return "geminiAPIKey"
        case .anthropic:      return "claudeAPIKey"
        case .openRouter:     return "openRouterAPIKey"
        case .kmaWeather:     return "kmaWeatherAPIKey"
        case .naverNews:      return "naverNewsAPIKey"
        case .dartDisclosure: return "dartDisclosureAPIKey"
        case .koreanLaw:      return "koreanLawAPIKey"
        }
    }

    /// App Store 빌드에서 표시할 provider인지
    var isVisibleInAppStore: Bool {
        switch self {
        case .openAI, .gemini, .anthropic, .openRouter,
             .kmaWeather, .naverNews, .dartDisclosure, .koreanLaw:
            return true
        }
    }
}
