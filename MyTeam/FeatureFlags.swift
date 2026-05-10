import Foundation

enum FeatureFlags {
    #if DEBUG
    static var planRunnerUniversalDocumentEnabled: Bool {
        UserDefaults.standard.bool(forKey: "MyTeam.FeatureFlags.planRunnerUniversalDocumentEnabled")
    }

    static func setPlanRunnerUniversalDocumentEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "MyTeam.FeatureFlags.planRunnerUniversalDocumentEnabled")
    }
    #else
    static var planRunnerUniversalDocumentEnabled: Bool { false }

    static func setPlanRunnerUniversalDocumentEnabled(_ enabled: Bool) {
        // Release에서는 무시
    }
    #endif
}
