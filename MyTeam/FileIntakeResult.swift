import Foundation

struct FileIntakeResult: Equatable {
    enum Status: String, Codable {
        case ready
        case unsupported
        case planned
        case blocked
        case tooLarge
        case readFailed
        case empty
    }

    let status: Status
    let request: FileIntakeRequest
    let extractedText: String?
    let userMessage: String
}
