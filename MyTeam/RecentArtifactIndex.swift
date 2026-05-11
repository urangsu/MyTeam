import Foundation

// MARK: - RecentArtifactIndexEntry

struct RecentArtifactIndexEntry: Codable, Equatable, Sendable {
    let artifactID: String
    let roomID: UUID
    let filename: String
    let artifactType: String
    let createdAt: Date
    let contentHash: String?
    let fileSizeBytes: Int64?

    var description: String {
        "\(filename) (\(artifactType)) @ \(createdAt.formatted(.iso8601))"
    }
}

// MARK: - RecentArtifactIndex

@MainActor
final class RecentArtifactIndex {
    private var entries: [RecentArtifactIndexEntry] = []
    private let maxEntriesPerRoom = 10

    /// 모든 entry 조회
    var allEntries: [RecentArtifactIndexEntry] {
        entries
    }

    /// 특정 room의 최근 artifact 조회
    func recentArtifacts(for roomID: UUID) -> [RecentArtifactIndexEntry] {
        entries
            .filter { $0.roomID == roomID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// 특정 roomID와 filename으로 entry 조회
    func entry(for artifactID: String, roomID: UUID) -> RecentArtifactIndexEntry? {
        entries.first { $0.artifactID == artifactID && $0.roomID == roomID }
    }

    /// 새로운 artifact를 index에 추가
    /// - markdown/txt artifact 우선
    /// - 중복 제거
    /// - room별 최대 10개 유지
    func add(_ entry: RecentArtifactIndexEntry) {
        // 중복 제거 (같은 artifactID + roomID는 한 번만)
        entries.removeAll { $0.artifactID == entry.artifactID && $0.roomID == entry.roomID }

        // 새 entry 추가
        entries.append(entry)

        // room별 최대 10개 유지
        let roomEntries = entries.filter { $0.roomID == entry.roomID }
        if roomEntries.count > maxEntriesPerRoom {
            let sorted = roomEntries.sorted { $0.createdAt > $1.createdAt }
            let idsToRemove = sorted.dropFirst(maxEntriesPerRoom).map { $0.artifactID }
            entries.removeAll { idsToRemove.contains($0.artifactID) && $0.roomID == entry.roomID }
        }
    }

    /// artifact index에서 제거
    func remove(artifactID: String, roomID: UUID) {
        entries.removeAll { $0.artifactID == artifactID && $0.roomID == roomID }
    }

    /// 모든 entry 제거
    func clear() {
        entries.removeAll()
    }

    /// 특정 room의 artifact 제거
    func clearRoom(_ roomID: UUID) {
        entries.removeAll { $0.roomID == roomID }
    }
}
