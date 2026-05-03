import Foundation

// MARK: - ActionLogEntry

struct ActionLogEntry: Codable {
    let ts: String           // ISO 8601
    let session: String
    let tool: String
    let input: [String: String]
    let result: String       // "success" | "failure" | "dry_run" | "blocked"
    let artifact: String?    // Workspace 상대 경로
    let error: String?

    func with(
        result: String,
        artifact: String? = nil,
        error: String? = nil
    ) -> ActionLogEntry {
        ActionLogEntry(
            ts: ts,
            session: session,
            tool: tool,
            input: input,
            result: result,
            artifact: artifact,
            error: error
        )
    }
}

// MARK: - ArtifactStore

final class ArtifactStore {
    static let shared = ArtifactStore()
    private init() {}

    var workspaceURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let url = appSupport.appendingPathComponent("MyTeam/Workspace")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    var actionLogURL: URL {
        workspaceURL.appendingPathComponent("action_log.jsonl")
    }

    // MARK: - Action Log (append-only JSONL)

    func appendActionLog(_ entry: ActionLogEntry) {
        guard let data = try? JSONEncoder().encode(entry),
              let line = String(data: data, encoding: .utf8) else { return }
        let logLine = line + "\n"
        let logURL = actionLogURL
        if FileManager.default.fileExists(atPath: logURL.path),
           let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(Data(logLine.utf8))
            try? handle.close()
        } else {
            try? logLine.write(to: logURL, atomically: false, encoding: .utf8)
        }
    }
}
