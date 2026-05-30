import Foundation

struct BrowserSnapshot: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let roomID: UUID
    let chainRunID: UUID?
    let url: String
    let title: String?
    let text: String
    let capturedAt: Date
}

