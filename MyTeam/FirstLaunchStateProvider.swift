import Foundation

// MARK: - FirstLaunchStateProvider

@MainActor
enum FirstLaunchStateProvider {
    static func makeState(
        hasSeenOnboarding: Bool = false,
        apiKeyAvailable: Bool = false,
        networkAvailable: Bool = true,
        artifactCount: Int = 0,
        connectorState: ConnectorReadyState = .notStarted
    ) -> FirstLaunchState {
        let capabilityMode = RuntimeCapabilityMode.detect(
            apiKeyAvailable: apiKeyAvailable,
            networkAvailable: networkAvailable,
            connectorState: connectorState
        )

        return FirstLaunchState(
            hasSeenOnboarding: hasSeenOnboarding,
            hasAPIKey: apiKeyAvailable,
            isOffline: !networkAvailable,
            capabilityMode: capabilityMode,
            hasCreatedFirstArtifact: artifactCount > 0
        )
    }

    static func currentState(
        hasAPIKey: Bool,
        isOffline: Bool = false,
        artifactCount: Int = 0,
        connectorState: ConnectorReadyState = .notStarted
    ) -> FirstLaunchState {
        return makeState(
            hasSeenOnboarding: UserDefaults.standard.bool(forKey: "MyTeam.hasSeenOnboarding"),
            apiKeyAvailable: hasAPIKey,
            networkAvailable: !isOffline,
            artifactCount: artifactCount,
            connectorState: connectorState
        )
    }

    static func markOnboardingSeen() {
        UserDefaults.standard.set(true, forKey: "MyTeam.hasSeenOnboarding")
    }
}
