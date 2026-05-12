import Foundation

enum FeatureFlags {
    #if DEBUG
    static var buildConfiguration: String { "Debug" }
    static var planRunnerUniversalDocumentEnabled: Bool {
        UserDefaults.standard.bool(forKey: "MyTeam.FeatureFlags.planRunnerUniversalDocumentEnabled")
    }

    static var planRunnerToggleVisible: Bool { true }
    static var debugDiagnosticsVisible: Bool { true }

    static func setPlanRunnerUniversalDocumentEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "MyTeam.FeatureFlags.planRunnerUniversalDocumentEnabled")
    }
    #else
    static var buildConfiguration: String { "Release" }
    static var planRunnerUniversalDocumentEnabled: Bool { false }
    static var planRunnerToggleVisible: Bool { false }
    static var debugDiagnosticsVisible: Bool { false }

    static func setPlanRunnerUniversalDocumentEnabled(_ enabled: Bool) {
        // Release에서는 무시
    }
    #endif
}
