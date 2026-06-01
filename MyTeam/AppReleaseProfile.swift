import Foundation

// MARK: - AppReleaseProfile

/// 앱 배포 환경을 구분합니다.
/// - debug: 개발용 — Playwright MCP, 실험 기능 전부 허용
/// - appStore: App Store 배포 — external process/npx 완전 차단, 사용자 키 + 공식 API 중심
/// - directDownload: 직접 다운로드 — 고급 기능 일부 허용
/// - powerUser: 개발자 모드에서만 노출되는 최고 권한
enum AppReleaseProfile: String, CaseIterable {
    case debug
    case appStore
    case directDownload
    case powerUser

    /// 현재 빌드의 프로필. Release 빌드는 appStore, Debug 빌드는 debug.
    nonisolated static var current: AppReleaseProfile {
        #if DEBUG
        return .debug
        #else
        return .appStore
        #endif
    }

    nonisolated var policy: RuntimeFeaturePolicy {
        switch self {
        case .debug:
            return RuntimeFeaturePolicy(
                allowsExternalProcess:          true,
                allowsPlaywrightMCP:            true,
                allowsExperimentalConnectors:   true,
                allowsVoiceAPI:                 true,
                allowsUserProvidedAPIKeys:       true,
                showsDeveloperDiagnostics:       true
            )
        case .appStore:
            return RuntimeFeaturePolicy(
                allowsExternalProcess:          false,
                allowsPlaywrightMCP:            false,
                allowsExperimentalConnectors:   false,
                allowsVoiceAPI:                 false,
                allowsUserProvidedAPIKeys:       true,
                showsDeveloperDiagnostics:       false
            )
        case .directDownload:
            return RuntimeFeaturePolicy(
                allowsExternalProcess:          true,
                allowsPlaywrightMCP:            true,   // optional — 사용자가 직접 활성화
                allowsExperimentalConnectors:   true,
                allowsVoiceAPI:                 false,
                allowsUserProvidedAPIKeys:       true,
                showsDeveloperDiagnostics:       false
            )
        case .powerUser:
            return RuntimeFeaturePolicy(
                allowsExternalProcess:          true,
                allowsPlaywrightMCP:            true,
                allowsExperimentalConnectors:   true,
                allowsVoiceAPI:                 true,
                allowsUserProvidedAPIKeys:       true,
                showsDeveloperDiagnostics:       true
            )
        }
    }
}

// MARK: - RuntimeFeaturePolicy

/// 런타임 기능 허용 정책. AppReleaseProfile로부터 파생됩니다.
struct RuntimeFeaturePolicy: Sendable {
    /// npx / node / external Process 실행 허용 여부
    let allowsExternalProcess: Bool
    /// Playwright MCP health check 및 실행 허용 여부
    let allowsPlaywrightMCP: Bool
    /// 실험적 커넥터(Exa 등) 노출 여부
    let allowsExperimentalConnectors: Bool
    /// 외부 음성 API (ElevenLabs 등) 허용 여부
    let allowsVoiceAPI: Bool
    /// 사용자가 직접 API 키를 입력해서 사용하는 BYOK 허용 여부
    let allowsUserProvidedAPIKeys: Bool
    /// 개발자 진단 UI 표시 여부
    let showsDeveloperDiagnostics: Bool
}
