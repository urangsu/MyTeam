import Foundation

enum DiagnosticsVisibilityPolicy {
    static var allowsVerboseDiagnostics: Bool {
        FeatureFlags.debugDiagnosticsVisible
    }

    static var allowsRawFailureCodes: Bool {
        FeatureFlags.debugDiagnosticsVisible
    }

    static var allowsToolInputSummary: Bool {
        FeatureFlags.debugDiagnosticsVisible
    }
}
