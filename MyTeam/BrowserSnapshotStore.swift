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
        let encodedData: Data
        do {
            encodedData = try JSONEncoder().encode(record)
        } catch {
            AppLog.error("Failed to encode snapshot: \(error)", .legacy)
            return
        }
        let roomID = record.roomID
        let chainRunID = record.chainRunID
        let recordID = record.id

        // Save to disk asynchronously
        Task.detached(priority: .background) { [encodedData, roomID, chainRunID, recordID] in
            let baseDir = AppPaths.applicationSupportDirectory
                .appendingPathComponent("browser_snapshots", isDirectory: true)
                .appendingPathComponent(roomID.uuidString, isDirectory: true)
                .appendingPathComponent(chainRunID.uuidString, isDirectory: true)

            let fileURL = baseDir.appendingPathComponent("\(recordID.uuidString).json")

            do {
                let fileManager = FileManager.default
                if !fileManager.fileExists(atPath: baseDir.path) {
                    try fileManager.createDirectory(at: baseDir, withIntermediateDirectories: true, attributes: nil)
                }

                try encodedData.write(to: fileURL, options: .atomic)
                AppLog.info("Successfully persisted snapshot to \(fileURL.path)", .legacy)
            } catch {
                AppLog.error("Failed to persist snapshot: \(error)", .legacy)
            }
        }
    }

    func get(_ id: UUID) -> BrowserSnapshotRecord? {
        if let cached = recordsByID[id] {
            return cached
        }

        // Try to load from disk by scanning the directory hierarchy recursively
        let baseDir = AppPaths.applicationSupportDirectory.appendingPathComponent("browser_snapshots", isDirectory: true)
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: baseDir.path) else { return nil }

        let targetFilename = "\(id.uuidString.lowercased()).json"
        let enumerator = fileManager.enumerator(
            at: baseDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.lastPathComponent.lowercased() == targetFilename {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let record = try JSONDecoder().decode(BrowserSnapshotRecord.self, from: data)
                    recordsByID[id] = record
                    return record
                } catch {
                    AppLog.error("Failed to read snapshot file at \(fileURL.path): \(error)", .legacy)
                }
            }
        }

        return nil
    }
}
