import Foundation

enum RecoveryAction: String, Codable, Equatable {
    case failFast
    case retryOnce
    case fallbackToTemplate
    case askUser
}
