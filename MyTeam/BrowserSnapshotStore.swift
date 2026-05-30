import Combine
import Foundation

struct BrowserSnapshotRecord: Identifiable, Codable, Sendable {
    let id: UUID
    let roomID: UUID
    let chainRunID: UUID
    let url: String
    let title: String?
    let text: String
    let capturedAt: Date
    let sourceType: AgentWindowManager.SourceType
}

@MainActor
final class BrowserSnapshotStore: ObservableObject {
    static let shared = BrowserSnapshotStore()

    @Published private(set) var recordsByID: [UUID: BrowserSnapshotRecord] = [:]

    func save(_ record: BrowserSnapshotRecord) {
        recordsByID[record.id] = record
    }

    func get(_ id: UUID) -> BrowserSnapshotRecord? {
        recordsByID[id]
    }
}
