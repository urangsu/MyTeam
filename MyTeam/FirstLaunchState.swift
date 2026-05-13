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
