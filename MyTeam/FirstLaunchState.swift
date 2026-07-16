import Foundation

// MARK: - FirstLaunchState

struct FirstLaunchState: Codable, Equatable, Sendable {
    let hasSeenOnboarding: Bool
    let hasAPIKey: Bool
    let isOffline: Bool
    let capabilityMode: RuntimeCapabilityMode
    let hasCreatedFirstArtifact: Bool

    init(
        hasSeenOnboarding: Bool = false,
        hasAPIKey: Bool = false,
        isOffline: Bool = false,
        capabilityMode: RuntimeCapabilityMode = .localOnly,
        hasCreatedFirstArtifact: Bool = false
    ) {
        self.hasSeenOnboarding = hasSeenOnboarding
        self.hasAPIKey = hasAPIKey
        self.isOffline = isOffline
        self.capabilityMode = capabilityMode
        self.hasCreatedFirstArtifact = hasCreatedFirstArtifact
    }

    static let empty = FirstLaunchState()

    /// Returns true if user should see first-launch onboarding
    var shouldShowOnboarding: Bool {
        !hasSeenOnboarding
    }

    /// Returns true if user should see local-only mode guidance
    var shouldShowLocalOnlyGuidance: Bool {
        shouldShowOnboarding && !hasAPIKey && capabilityMode == .localOnly
    }

    /// Returns true if user should see offline state message
    var shouldShowOfflineMessage: Bool {
        isOffline && !shouldShowOnboarding
    }

    /// Returns true if user should see first-result activation actions
    var shouldShowFirstResultActions: Bool {
        hasCreatedFirstArtifact && !hasSeenOnboarding
    }

    func updated(
        hasSeenOnboarding: Bool? = nil,
        hasAPIKey: Bool? = nil,
        isOffline: Bool? = nil,
        capabilityMode: RuntimeCapabilityMode? = nil,
        hasCreatedFirstArtifact: Bool? = nil
    ) -> FirstLaunchState {
        FirstLaunchState(
            hasSeenOnboarding: hasSeenOnboarding ?? self.hasSeenOnboarding,
            hasAPIKey: hasAPIKey ?? self.hasAPIKey,
            isOffline: isOffline ?? self.isOffline,
            capabilityMode: capabilityMode ?? self.capabilityMode,
            hasCreatedFirstArtifact: hasCreatedFirstArtifact ?? self.hasCreatedFirstArtifact
        )
    }
}

enum FirstLaunchPresentation {
    struct Content: Equatable, Sendable {
        let iconName: String
        let title: String
        let subtitle: String
    }

    nonisolated static func content(for state: FirstLaunchState) -> Content {
        switch state.capabilityMode {
        case .localOnly:
            if state.isOffline {
                return Content(
                    iconName: "wifi.slash",
                    title: "네트워크 연결 없음",
                    subtitle: "네트워크 연결이 없어 AI 응답은 제한됩니다."
                )
            }
            return Content(
                iconName: "sparkles",
                title: "로컬 기능부터 바로 시작",
                subtitle: "회의록 양식, 체크리스트, 파일 읽기, 오늘 할 일은 바로 사용할 수 있습니다."
            )
        case .connectorLimited:
            return Content(
                iconName: "exclamationmark.triangle.fill",
                title: "일부 연결 기능 준비 중",
                subtitle: "메일·일정 등 외부 서비스는 연결 및 승인 상태에 따라 제한됩니다."
            )
        case .aiEnabled:
            return Content(
                iconName: "checkmark.circle.fill",
                title: "AI 대화 연결됨",
                subtitle: "연결한 AI로 대화할 수 있습니다. 외부 서비스는 각각의 연결 상태를 확인해 주세요."
            )
        }
    }
}
