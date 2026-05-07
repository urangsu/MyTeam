import Foundation
import Combine

enum CharacterAccessState: Equatable {
    case owned
    case locked
    case comingSoon
}

final class CharacterEntitlementManager: ObservableObject {
    static let shared = CharacterEntitlementManager()

    func accessState(for character: CharacterDLC) -> CharacterAccessState {
        if character.isBuiltIn { return .owned }
        if character.isComingSoon { return .comingSoon }
        return .locked
    }

    func isOwned(_ character: CharacterDLC) -> Bool {
        accessState(for: character) == .owned
    }
}
