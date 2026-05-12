import Foundation

enum MemorySensitivity: String, Codable, Equatable, Sendable {
    case publicLow
    case workspace
    case personal
    case confidential
    case secret
}
