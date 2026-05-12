import CryptoKit
import Foundation

// MARK: - ActionLogEntry

struct ActionLogEntry: Codable, Sendable {
    let ts: String           // ISO 8601
    let session: String
    let tool: String
    let inputSummary: [String: String]
    let inputHash: String
    let redactedFields: [String]
    let result: String       // "success" | "failure" | "dry_run" | "blocked"
    let artifact: String?    // Workspace 상대 경로
    let error: String?
    let declaredRisk: String?
    let registryRisk: String?
    let effectiveRisk: String?
    let failureCode: String?

    func with(
        result: String,
        artifact: String? = nil,
        error: String? = nil,
        declaredRisk: String? = nil,
        registryRisk: String? = nil,
        effectiveRisk: String? = nil,
        failureCode: String? = nil
    ) -> ActionLogEntry {
        ActionLogEntry(
            ts: ts,
            session: session,
            tool: tool,
            inputSummary: inputSummary,
            inputHash: inputHash,
            redactedFields: redactedFields,
            result: result,
            artifact: artifact,
            error: error,
            declaredRisk: declaredRisk,
            registryRisk: registryRisk,
            effectiveRisk: effectiveRisk,
            failureCode: failureCode
        )
    }

    init(
        ts: String,
        session: String,
        tool: String,
        input: [String: String],
        result: String,
        artifact: String?,
        error: String?,
        declaredRisk: String?,
        registryRisk: String?,
        effectiveRisk: String?,
        failureCode: String?
    ) {
        let redacted = ActionLogEntry.redact(input: input)
        self.ts = ts
        self.session = session
        self.tool = tool
        self.inputSummary = redacted.summary
        self.inputHash = redacted.hash
        self.redactedFields = redacted.redactedFields
        self.result = result
        self.artifact = artifact
        self.error = error
        self.declaredRisk = declaredRisk
        self.registryRisk = registryRisk
        self.effectiveRisk = effectiveRisk
        self.failureCode = failureCode
    }

    init(
        ts: String,
        session: String,
        tool: String,
        inputSummary: [String: String],
        inputHash: String,
        redactedFields: [String],
        result: String,
        artifact: String?,
        error: String?,
        declaredRisk: String?,
        registryRisk: String?,
        effectiveRisk: String?,
        failureCode: String?
    ) {
        self.ts = ts
        self.session = session
        self.tool = tool
        self.inputSummary = inputSummary
        self.inputHash = inputHash
        self.redactedFields = redactedFields
        self.result = result
        self.artifact = artifact
        self.error = error
        self.declaredRisk = declaredRisk
        self.registryRisk = registryRisk
        self.effectiveRisk = effectiveRisk
        self.failureCode = failureCode
    }

    private static func redact(input: [String: String]) -> (summary: [String: String], hash: String, redactedFields: [String]) {
        let sortedKeys = input.keys.sorted()
        var summary: [String: String] = [:]
        var redactedFields: [String] = []

        for key in sortedKeys {
            let value = input[key] ?? ""
            let normalizedKey = key.lowercased()
            let isSensitive = ["content", "sourcetext", "body", "token", "key", "secret", "auth", "password"].contains(where: { normalizedKey.contains($0) })
            if isSensitive {
                redactedFields.append(key)
            }

            let digest = SHA256.hash(data: Data(value.utf8))
            let hash = digest.map { String(format: "%02x", $0) }.joined()
            summary[key] = "[len=\(value.count) hash=\(String(hash.prefix(12)))]"
        }

        let canonical = sortedKeys.map { key in
            "\(key)=\(input[key] ?? "")"
        }.joined(separator: "\u{1f}")
        let digest = SHA256.hash(data: Data(canonical.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return (summary, hash, redactedFields)
    }
}

enum ActionLogRedactionVerifier {
    static func isEnabled() -> Bool {
        let entry = ActionLogEntry(
            ts: "1970-01-01T00:00:00Z",
            session: "redaction-check",
            tool: "probe",
            input: [
                "content": "RAW-CONTENT",
                "sourceText": "RAW-SOURCE",
                "body": "RAW-BODY",
                "token": "RAW-TOKEN",
                "key": "RAW-KEY",
                "secret": "RAW-SECRET",
                "auth": "RAW-AUTH",
                "password": "RAW-PASSWORD"
            ],
            result: "blocked",
            artifact: nil,
            error: nil,
            declaredRisk: nil,
            registryRisk: nil,
            effectiveRisk: nil,
            failureCode: nil
        )

        guard let data = try? JSONEncoder().encode(entry),
              let text = String(data: data, encoding: .utf8) else {
            return false
        }

        return !text.contains("RAW-CONTENT")
            && !text.contains("RAW-SOURCE")
            && !text.contains("RAW-BODY")
            && !text.contains("RAW-TOKEN")
            && !text.contains("RAW-KEY")
            && !text.contains("RAW-SECRET")
            && !text.contains("RAW-AUTH")
            && !text.contains("RAW-PASSWORD")
    }
}

// MARK: - ArtifactType

enum ArtifactType: String, Codable {
    case report       = "report"
    case presentation = "presentation"
    case spreadsheet  = "spreadsheet"
    case text         = "text"
    case cloud        = "cloud"
    case other        = "other"
}

// MARK: - IndexedArtifact

struct IndexedArtifact: Codable, Sendable {
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

    func appendActionLog(_ entry: ActionLogEntry) async {
        let data = await MainActor.run { try? JSONEncoder().encode(entry) }
        guard let data,
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

    func loadActionLogEntries() async -> [ActionLogEntry] {
        let logURL = actionLogURL
        guard FileManager.default.fileExists(atPath: logURL.path),
              let data = try? Data(contentsOf: logURL) else {
            return []
        }

        guard let text = await MainActor.run(body: { String(data: data, encoding: .utf8) }) else {
            return []
        }
        return await MainActor.run {
            let decoder = JSONDecoder()
            return text
                .split(whereSeparator: { $0.isNewline })
                .compactMap { line in
                    guard !line.isEmpty else { return nil }
                    return try? decoder.decode(ActionLogEntry.self, from: Data(line.utf8))
                }
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
