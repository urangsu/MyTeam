import Foundation

enum MyTeamToolCategory: String, CaseIterable, Sendable, Hashable {
    case briefing
    case document
    case spreadsheet
    case externalInfo
    case calendar
    case mail
    case voice
    case system
}

enum MyTeamPermissionLevel: String, Codable, Sendable, Hashable {
    case readOnly
    case draftOnly
    case writeRequiresApproval
    case destructiveRequiresApproval
    case externalSendRequiresApproval
}

enum MyTeamToolImplementationStatus: String, Sendable {
    case available
    case needsConnection
    case needsValidation
    case comingSoon
    case disabledByDistribution
    case blockedByPolicy
}

enum MyTeamCredentialProvider: Sendable, Hashable {
    case external(ExternalProvider)
    case assistant(AssistantConnector.Provider)

    nonisolated var externalProvider: ExternalProvider? {
        if case .external(let provider) = self { return provider }
        return nil
    }

    nonisolated var assistantProvider: AssistantConnector.Provider? {
        if case .assistant(let provider) = self { return provider }
        return nil
    }

    nonisolated var displayName: String {
        switch self {
        case .external(let provider):
            return provider.displayName
        case .assistant(let provider):
            return provider.displayName
        }
    }
}

struct MyTeamCredentialRequirement: Sendable, Hashable {
    let provider: MyTeamCredentialProvider
    let reason: String
}

struct MyTeamToolDescriptor: Identifiable, Sendable, Hashable {
    let id: String
    let displayName: String
    let shortDescription: String
    let category: MyTeamToolCategory
    let requiredCredential: MyTeamCredentialRequirement?
    let permissionLevel: MyTeamPermissionLevel
    let isImplemented: Bool
    let isUserFacing: Bool
    let supportedDistributionChannels: Set<DistributionChannel>
    let relatedProvider: ExternalProvider?
}

enum MyTeamToolRegistry {
    nonisolated static let all: [MyTeamToolDescriptor] = [
        MyTeamToolDescriptor(
            id: "briefing.today",
            displayName: "오늘 브리핑",
            shortDescription: "날씨, 일정, 뉴스, 공시를 업무 시작용으로 묶어 봅니다.",
            category: .briefing,
            requiredCredential: nil,
            permissionLevel: .readOnly,
            isImplemented: true,
            isUserFacing: true,
            supportedDistributionChannels: [.appStore, .direct, .developer],
            relatedProvider: nil
        ),
        MyTeamToolDescriptor(
            id: "news.search",
            displayName: "뉴스 브리핑",
            shortDescription: "뉴스 검색 결과의 제목과 설명을 출처와 함께 정리합니다.",
            category: .externalInfo,
            requiredCredential: nil,
            permissionLevel: .readOnly,
            isImplemented: true,
            isUserFacing: true,
            supportedDistributionChannels: [.appStore, .direct, .developer],
            relatedProvider: .naverNews
        ),
        MyTeamToolDescriptor(
            id: "dart.disclosures.search",
            displayName: "공시 조회",
            shortDescription: "DART 공시를 조회하고 원문 출처를 확인합니다.",
            category: .externalInfo,
            requiredCredential: MyTeamCredentialRequirement(provider: .external(.dartDisclosure), reason: "DART 개인 API 키 연결이 필요합니다."),
            permissionLevel: .readOnly,
            isImplemented: true,
            isUserFacing: true,
            supportedDistributionChannels: [.appStore, .direct, .developer],
            relatedProvider: .dartDisclosure
        ),
        MyTeamToolDescriptor(
            id: "weather.current",
            displayName: "날씨 조회",
            shortDescription: "기상청 단기 데이터를 확인합니다.",
            category: .externalInfo,
            requiredCredential: nil,
            permissionLevel: .readOnly,
            isImplemented: true,
            isUserFacing: true,
            supportedDistributionChannels: [.appStore, .direct, .developer],
            relatedProvider: .kmaWeather
        ),
        MyTeamToolDescriptor(
            id: "law.search",
            displayName: "법령 검색",
            shortDescription: "공식 법령 출처를 기준으로 법령과 조문을 찾습니다.",
            category: .externalInfo,
            requiredCredential: nil,
            permissionLevel: .readOnly,
            isImplemented: true,
            isUserFacing: true,
            supportedDistributionChannels: [.appStore, .direct, .developer],
            relatedProvider: .koreanLaw
        ),
        MyTeamToolDescriptor(
            id: "calendar.events.today",
            displayName: "일정 확인",
            shortDescription: "오늘 일정과 회의 준비 사항을 확인합니다.",
            category: .calendar,
            requiredCredential: MyTeamCredentialRequirement(provider: .assistant(.googleCalendar), reason: "Google Calendar 읽기 연결이 필요합니다."),
            permissionLevel: .readOnly,
            isImplemented: true,
            isUserFacing: true,
            supportedDistributionChannels: [.appStore, .direct, .developer],
            relatedProvider: nil
        ),
        MyTeamToolDescriptor(
            id: "document.meetingMinutes",
            displayName: "회의록 작성",
            shortDescription: "대화나 메모를 회의록 초안으로 정리합니다.",
            category: .document,
            requiredCredential: nil,
            permissionLevel: .draftOnly,
            isImplemented: true,
            isUserFacing: true,
            supportedDistributionChannels: [.appStore, .direct, .developer],
            relatedProvider: nil
        ),
        MyTeamToolDescriptor(
            id: "document.rewrite",
            displayName: "문서 다듬기",
            shortDescription: "문장과 문서를 목적에 맞게 정리합니다.",
            category: .document,
            requiredCredential: nil,
            permissionLevel: .draftOnly,
            isImplemented: true,
            isUserFacing: true,
            supportedDistributionChannels: [.appStore, .direct, .developer],
            relatedProvider: nil
        ),
        MyTeamToolDescriptor(
            id: "spreadsheet.postprocess",
            displayName: "엑셀 후처리",
            shortDescription: "표 정리, 요약, 보고용 형태 변환을 준비합니다.",
            category: .spreadsheet,
            requiredCredential: nil,
            permissionLevel: .draftOnly,
            isImplemented: true,
            isUserFacing: true,
            supportedDistributionChannels: [.appStore, .direct, .developer],
            relatedProvider: nil
        ),
        MyTeamToolDescriptor(
            id: "spreadsheet.googleSheets.read",
            displayName: "Google Sheets 읽기",
            shortDescription: "스프레드시트 URL 또는 ID로 값을 읽어옵니다.",
            category: .spreadsheet,
            requiredCredential: MyTeamCredentialRequirement(provider: .assistant(.googleSheets), reason: "Google Sheets 읽기 연결이 필요합니다."),
            permissionLevel: .readOnly,
            isImplemented: true,
            isUserFacing: true,
            supportedDistributionChannels: [.appStore, .direct, .developer],
            relatedProvider: nil
        ),
        MyTeamToolDescriptor(
            id: "spreadsheet.merge",
            displayName: "엑셀 병합",
            shortDescription: "여러 표를 합치는 작업을 준비합니다.",
            category: .spreadsheet,
            requiredCredential: nil,
            permissionLevel: .draftOnly,
            isImplemented: false,
            isUserFacing: false,
            supportedDistributionChannels: [.appStore, .direct, .developer],
            relatedProvider: nil
        ),
        MyTeamToolDescriptor(
            id: "voice.supertonic.preview",
            displayName: "캐릭터 목소리",
            shortDescription: "Supertonic3 캐릭터 목소리를 테스트합니다.",
            category: .voice,
            requiredCredential: nil,
            permissionLevel: .readOnly,
            isImplemented: true,
            isUserFacing: true,
            supportedDistributionChannels: [.developer],
            relatedProvider: nil
        ),
        MyTeamToolDescriptor(
            id: "voice.bubbleSpeech.preview",
            displayName: "뽀글뽀글 말하기",
            shortDescription: "캐릭터 목소리를 음절 리듬으로 재구성합니다.",
            category: .voice,
            requiredCredential: nil,
            permissionLevel: .readOnly,
            isImplemented: true,
            isUserFacing: true,
            supportedDistributionChannels: [.developer],
            relatedProvider: nil
        ),
        MyTeamToolDescriptor(
            id: "system.connectionCenter",
            displayName: "연결 설정",
            shortDescription: "필요한 개인 키와 연결 상태를 확인합니다.",
            category: .system,
            requiredCredential: nil,
            permissionLevel: .writeRequiresApproval,
            isImplemented: true,
            isUserFacing: true,
            supportedDistributionChannels: [.appStore, .direct, .developer],
            relatedProvider: nil
        )
    ]

    nonisolated static var userFacingTools: [MyTeamToolDescriptor] {
        all.filter(\.isUserFacing)
    }

    nonisolated static func descriptor(id: String) -> MyTeamToolDescriptor? {
        all.first { $0.id == id }
    }

    nonisolated static func tools(using provider: ExternalProvider) -> [MyTeamToolDescriptor] {
        all.filter {
            $0.relatedProvider == provider || $0.requiredCredential?.provider.externalProvider == provider
        }
    }

    nonisolated static func tools(using provider: AssistantConnector.Provider) -> [MyTeamToolDescriptor] {
        all.filter {
            $0.requiredCredential?.provider.assistantProvider == provider
        }
    }

    nonisolated static func providerUsageLabels(for provider: ExternalProvider) -> [String] {
        let registryLabels = tools(using: provider).map(\.displayName)
        if !registryLabels.isEmpty { return registryLabels }

        switch provider {
        case .openAI, .gemini, .anthropic, .openRouter:
            return ["문서 작성", "회의록 작성", "요약", "브리핑"]
        case .kmaWeather:
            return ["오늘 날씨", "아침 브리핑"]
        case .naverNews:
            return ["뉴스 브리핑", "경제 브리핑", "이슈 검색"]
        case .dartDisclosure:
            return ["공시 조회", "경제 브리핑", "기업 리포트"]
        case .koreanLaw:
            return ["법령 검색", "규정 검토"]
        }
    }
}
