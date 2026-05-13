import Foundation

// MARK: - RuntimeCapabilityMode

enum RuntimeCapabilityMode: String, Codable, Equatable, Sendable {
    case localOnly
    case aiEnabled
    case connectorLimited

    var title: String {
        switch self {
        case .localOnly:
            return "로컬 기능만 사용 가능"
        case .aiEnabled:
            return "AI 기능 사용 가능"
        case .connectorLimited:
            return "연결 기능 준비 중"
        }
    }

    var shortMessage: String {
        switch self {
        case .localOnly:
            return "API 키를 설정하여 AI 기능을 사용할 수 있습니다."
        case .aiEnabled:
            return "모든 기능을 사용할 수 있습니다."
        case .connectorLimited:
            return "Calendar 읽기는 준비 중입니다. 외부 쓰기는 실행되지 않습니다."
        }
    }

    var detailedMessage: String {
        switch self {
        case .localOnly:
            return "AI 응답을 사용하려면 설정에서 API 키를 연결해 주세요. 지금은 로컬 파일 정리, 문서 템플릿, 스케줄 확인 기능부터 사용할 수 있습니다."
        case .aiEnabled:
            return "요약, 보고서, 문서 변환 등 AI 기능을 모두 사용할 수 있습니다."
        case .connectorLimited:
            return "Google Calendar 읽기 연결은 준비 중입니다. 메일 발송이나 일정 생성은 자동 실행하지 않습니다."
        }
    }

    static func detect(
        apiKeyAvailable: Bool,
        networkAvailable: Bool,
        connectorState: ConnectorReadyState = .notStarted
    ) -> RuntimeCapabilityMode {
        guard apiKeyAvailable else { return .localOnly }
        guard networkAvailable else { return .localOnly }

        if connectorState == .ready {
            return .aiEnabled
        } else if connectorState == .preparing {
            return .connectorLimited
        }

        return .aiEnabled
    }
}

// MARK: - OfflineStateMessage

struct OfflineStateMessage {
    static let title = "네트워크 연결 없음"
    static let message = "네트워크 연결이 없어 AI 응답은 제한됩니다. 로컬 파일/문서 기능과 저장된 작업은 계속 사용할 수 있습니다."
}

// MARK: - ConnectorReadyState

enum ConnectorReadyState: String, Codable, Equatable, Sendable {
    case notStarted
    case preparing
    case ready
    case failed
}
