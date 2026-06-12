import Foundation

enum Supertonic3ReleaseGate {
    nonisolated static let licenseVerifiedForAppStore = Supertonic3TTSConfig.isLicenseVerifiedForAppStore
    nonisolated static let modelRedistributionApproved = Supertonic3TTSConfig.isModelRedistributionApproved
    nonisolated static let commercialProductGateApproved = Supertonic3TTSConfig.isCommercialProductGateApproved

    nonisolated static var bundledModelValidated: Bool {
        (try? Supertonic3BundledModelLocator.validateRequiredFiles()) != nil
    }

    nonisolated static var isAppStoreApproved: Bool {
        licenseVerifiedForAppStore
            && modelRedistributionApproved
            && commercialProductGateApproved
            && bundledModelValidated
    }
}
