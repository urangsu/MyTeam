import Foundation

// MARK: - ConnectorFailureCode

/// 외부 API / 커넥터 실패 원인 분류.
/// 사용자에게는 이 코드를 직접 노출하지 않고, 사람이 이해할 수 있는 문구로 변환합니다.
enum ConnectorFailureCode: String, Codable, Sendable, Equatable {
    case missingAPIKey          // 키가 연결되지 않음
    case invalidAPIKey          // 키가 올바르지 않음
    case permissionDenied       // 권한 부족
    case quotaExceeded          // 사용량 한도 초과
    case rateLimited            // 일시적 요청 속도 제한
    case providerUnavailable    // 서비스 점검 등 일시 불가
    case networkError           // 네트워크 오류
    case responseParseFailed    // 응답 파싱 실패
    case unsupportedRegion      // 지역 미지원
    case releaseProfileBlocked  // App Store 배포 정책으로 차단

    // MARK: - 사용자 표시 문구

    func userMessage(for provider: ExternalProvider? = nil) -> String {
        let name = provider?.displayName ?? "서비스"
        switch self {
        case .missingAPIKey:
            return "\(name) 키가 아직 연결되지 않았어요."
        case .invalidAPIKey:
            return "\(name) 인증키가 올바르지 않은 것 같아요."
        case .permissionDenied:
            return "\(name) 키의 권한이 부족해요."
        case .quotaExceeded:
            return "\(name) 사용량 한도에 도달했어요. 잠시 후 다시 시도해 주세요."
        case .rateLimited:
            return "요청이 너무 빠르게 들어왔어요. 잠시 후 다시 시도해 주세요."
        case .providerUnavailable:
            return "\(name) 서비스가 일시적으로 응답하지 않아요."
        case .networkError:
            return "네트워크 연결을 확인해 주세요."
        case .responseParseFailed:
            return "\(name) 응답을 읽지 못했어요. 잠시 후 다시 시도해 주세요."
        case .unsupportedRegion:
            return "\(name) 서비스는 현재 이 지역에서 지원되지 않아요."
        case .releaseProfileBlocked:
            return "이 기능은 현재 배포 버전에서 사용할 수 없어요."
        }
    }

    // MARK: - 복구 액션 힌트

    /// 사용자에게 제안할 복구 액션 종류
    enum RecoveryHint {
        case connectKey         // 키 연결하기
        case reEnterKey         // 키 다시 입력하기
        case openKeyGuide       // 발급 안내 보기
        case openProviderSite   // 서비스 사이트 열기
        case retryLater         // 나중에 다시 시도
        case checkNetwork       // 네트워크 확인
    }

    var recoveryHints: [RecoveryHint] {
        switch self {
        case .missingAPIKey:
            return [.connectKey, .openKeyGuide]
        case .invalidAPIKey:
            return [.reEnterKey, .openKeyGuide]
        case .permissionDenied:
            return [.openProviderSite, .openKeyGuide]
        case .quotaExceeded:
            return [.retryLater, .openProviderSite]
        case .rateLimited:
            return [.retryLater]
        case .providerUnavailable:
            return [.retryLater, .openProviderSite]
        case .networkError:
            return [.checkNetwork, .retryLater]
        case .responseParseFailed:
            return [.retryLater]
        case .unsupportedRegion:
            return [.openProviderSite]
        case .releaseProfileBlocked:
            return []
        }
    }
}
