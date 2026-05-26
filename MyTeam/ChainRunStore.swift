import Combine
import Foundation

@MainActor
final class ChainRunStore: ObservableObject {
    static let shared = ChainRunStore()

    @Published private(set) var latestRunByRoomID: [UUID: ChainRun] = [:]
    @Published private(set) var latestRunByID: [UUID: ChainRun] = [:]
    @Published private(set) var recentRunsByRoomID: [UUID: [ChainRun]] = [:]

    func upsert(_ run: ChainRun) {
        latestRunByRoomID[run.roomID] = run
        latestRunByID[run.id] = run
        var runs = recentRunsByRoomID[run.roomID, default: []]
        if let idx = runs.firstIndex(where: { $0.id == run.id }) {
            runs[idx] = run
        } else {
            runs.insert(run, at: 0)
        }
        recentRunsByRoomID[run.roomID] = Array(runs.prefix(5))
    }

    func latestRun(for roomID: UUID) -> ChainRun? {
        latestRunByRoomID[roomID]
    }

    func appendArtifact(_ artifactID: String, chainRunID: UUID, roomID: UUID) {
        guard var run = latestRunByID[chainRunID] ?? latestRunByRoomID[roomID] else { return }
        guard run.id == chainRunID, run.roomID == roomID else { return }
        if !run.artifacts.contains(artifactID) {
            run.artifacts.append(artifactID)
            run.updatedAt = Date()
            upsert(run)
        }
    }
}
