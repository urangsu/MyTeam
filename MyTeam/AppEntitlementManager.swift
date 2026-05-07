import Foundation
import Combine

final class AppEntitlementManager: ObservableObject {
    static let shared = AppEntitlementManager()

    @Published private(set) var currentPlan: MyTeamPlan = .free

    var currentLimits: PlanLimits {
        MonetizationPlanCatalog.limits(for: currentPlan)
    }

    func hasProAccess() -> Bool {
        currentPlan == .pro
    }

    func canUseBYOK() -> Bool {
        true
    }

    func isCharacterOwned(_ character: CharacterDLC) -> Bool {
        CharacterEntitlementManager.shared.isOwned(character)
    }

#if DEBUG
    func setDebugPlan(_ plan: MyTeamPlan) {
        currentPlan = plan
    }
#endif
}
