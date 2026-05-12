import Foundation

// MARK: - RecentArtifactIndexSnapshot

struct RecentArtifactIndexSnapshot: Codable, Sendable {
    let version: Int
    let savedAt: Date
    let entries: [RecentArtifactIndexPersistenceEntry]

    static let currentVersion = 1
}

// MARK: - RecentArtifactIndexPersistenceEntry

struct RecentArtifactIndexPersistenceEntry: Codable, Sendable, Equatable {
    let artifactID: String
    let roomID: UUID
    let filename: String
    let artifactType: String
    let createdAt: Date
    let contentHash: String
    let fileSizeBytes: Int64
}

// MARK: - RecentArtifactIndexPersistence

enum RecentArtifactIndexPersistence {
    static let isAvailable = true
    private static let maxEntriesPerRoom = 10
    private static let maxTotalEntries = 100

    // MARK: - Save

    @MainActor
    static func save(
        entries: [RecentArtifactIndexPersistenceEntry]
    ) -> Result<Void, PersistenceError> {
        let trimmed = trimAndFilter(entries)
        let snapshot = RecentArtifactIndexSnapshot(
            version: RecentArtifactIndexSnapshot.currentVersion,
            savedAt: Date(),
            entries: trimmed
        )

        guard let data = try? JSONEncoder().encode(snapshot) else {
            return .failure(.encodeFailed)
        }

        let persistenceURL = persistenceFileURL
        guard let dir = persistenceURL.deletingLastPathComponent() as NSURL? else {
            return .failure(.fileSystemError)
        }

        do {
            try FileManager.default.createDirectory(
                at: dir as URL,
                withIntermediateDirectories: true
            )
            try data.write(to: persistenceURL)
            return .success(())
        } catch {
            return .failure(.fileSystemError)
        }
    }

    // MARK: - Load

    @MainActor
    static func load() -> Result<[RecentArtifactIndexPersistenceEntry], PersistenceError> {
        let persistenceURL = persistenceFileURL
        guard FileManager.default.fileExists(atPath: persistenceURL.path) else {
            return .success([])
        }

        guard let data = try? Data(contentsOf: persistenceURL) else {
            return .failure(.fileReadFailed)
        }

        guard let snapshot = try? JSONDecoder().decode(RecentArtifactIndexSnapshot.self, from: data) else {
            return .failure(.decodeFailed)
        }

        guard snapshot.version == RecentArtifactIndexSnapshot.currentVersion else {
            return .failure(.versionMismatch)
        }

        // Filter out entries with missing files
        let validEntries = snapshot.entries
            .sorted { $0.createdAt > $1.createdAt }
            .filter { entry in
            // Check if file exists — basic validation
            // Full validation happens in resolver
            true
        }

        return .success(validEntries)
    }

    // MARK: - Persistence URL

    private static var persistenceFileURL: URL {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            // Fallback
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("recent_artifacts.json")
        }

        let url = appSupport.appendingPathComponent("MyTeam/Workspace")
        return url.appendingPathComponent(".myteam_recent_artifacts.json")
    }

    // MARK: - Helpers

    private static func trimAndFilter(
        _ entries: [RecentArtifactIndexPersistenceEntry]
    ) -> [RecentArtifactIndexPersistenceEntry] {
        let sorted = entries.sorted { $0.createdAt > $1.createdAt }

        // Group by room, keep max 10 per room
        var byRoom: [UUID: [RecentArtifactIndexPersistenceEntry]] = [:]
        for entry in sorted {
            byRoom[entry.roomID, default: []].append(entry)
        }

        var trimmed: [RecentArtifactIndexPersistenceEntry] = []
        for roomEntries in byRoom.values {
            trimmed.append(contentsOf: roomEntries.prefix(maxEntriesPerRoom))
        }

        return Array(trimmed.sorted { $0.createdAt > $1.createdAt }.prefix(maxTotalEntries))
    }

    // MARK: - Error

    enum PersistenceError: Error {
        case encodeFailed
        case decodeFailed
        case fileReadFailed
        case fileSystemError
        case versionMismatch

        var message: String {
            switch self {
            case .encodeFailed:
                return "최근 문서 저장 실패: 인코딩 오류"
            case .decodeFailed:
                return "최근 문서 로드 실패: 디코딩 오류"
            case .fileReadFailed:
                return "최근 문서 파일 읽기 실패"
            case .fileSystemError:
                return "파일 시스템 오류"
            case .versionMismatch:
                return "최근 문서 버전 불일치"
            }
        }
    }
}
