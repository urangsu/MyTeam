import Foundation

struct BrowserExtractedSource: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let roomID: UUID
    let chainRunID: UUID?
    let title: String
    let url: String
    let provider: String
    let sourceType: AgentWindowManager.SourceType
    let extractedText: String
    let extractedAt: Date
}

