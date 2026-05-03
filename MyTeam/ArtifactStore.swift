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
        ActionLogEntry(ts: ts, session: session, tool: tool, input: input,
                       result: result, artifact: artifact, error: error)
    }
}

// MARK: - ArtifactType

enum ArtifactType: String, Codable {
    case report       = "report"
    case presentation = "presentation"
    case spreadsheet  = "spreadsheet"
    case text         = "text"
    case other        = "other"
}

// MARK: - IndexedArtifact

struct IndexedArtifact: Codable {
    let id: String          // UUID
    let workflowID: String  // session ID
    let title: String
    let type: ArtifactType
    let filename: String    // Workspace 내 파일명
    let path: String        // 절대 경로
    let preview: String     // 내용 첫 200자
    let createdAt: String   // ISO 8601
}

// MARK: - ArtifactStore (actor — 동시 접근 직렬화)

actor ArtifactStore {
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

    var actionLogURL: URL { workspaceURL.appendingPathComponent("action_log.jsonl") }
    var artifactIndexURL: URL { workspaceURL.appendingPathComponent("artifacts.json") }

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

    // MARK: - Artifact Index (artifacts.json)

    func registerArtifact(_ artifact: IndexedArtifact) {
        var list = loadArtifacts()
        list.append(artifact)
        guard let data = try? JSONEncoder().encode(list) else { return }
        try? data.write(to: artifactIndexURL, options: .atomic)
        AppLog.info("[ArtifactStore] 등록: \(artifact.filename) (\(artifact.type.rawValue))")
    }

    func loadArtifacts() -> [IndexedArtifact] {
        guard let data = try? Data(contentsOf: artifactIndexURL),
              let list = try? JSONDecoder().decode([IndexedArtifact].self, from: data) else {
            return []
        }
        return list
    }

    func artifacts(forWorkflowID id: String) -> [IndexedArtifact] {
        loadArtifacts().filter { $0.workflowID == id }
    }
}
