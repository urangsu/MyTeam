import CryptoKit
import Foundation

enum ArtifactIndexHealthStatus: String, Codable, Equatable, Sendable {
    case valid
    case missingFile
    case invalidExternalPath
    case invalidRelativePath
    case hashMismatch
    case metadataOnly
}

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
    let id: String
    let workflowID: String
    let title: String
    let type: ArtifactType
    let filename: String
    let relativePath: String
    let preview: String
    let createdAt: String
    let updatedAt: String?
    let contentHash: String?
    let fileSizeBytes: Int64?
    let roomID: String?
    let healthStatus: ArtifactIndexHealthStatus

    init(
        id: String,
        workflowID: String,
        title: String,
        type: ArtifactType,
        filename: String,
        relativePath: String,
        preview: String,
        createdAt: String,
        updatedAt: String? = nil,
        contentHash: String? = nil,
        fileSizeBytes: Int64? = nil,
        roomID: String? = nil,
        healthStatus: ArtifactIndexHealthStatus = .valid
    ) {
        self.id = id
        self.workflowID = workflowID
        self.title = title
        self.type = type
        self.filename = filename
        self.relativePath = relativePath
        self.preview = preview
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.contentHash = contentHash
        self.fileSizeBytes = fileSizeBytes
        self.roomID = roomID
        self.healthStatus = healthStatus
    }

    private enum CodingKeys: String, CodingKey {
        case id, workflowID, title, type, filename, relativePath, path, preview, createdAt, updatedAt, contentHash, fileSizeBytes, roomID, healthStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        workflowID = try container.decode(String.self, forKey: .workflowID)
        title = try container.decode(String.self, forKey: .title)
        type = try container.decode(ArtifactType.self, forKey: .type)
        filename = try container.decode(String.self, forKey: .filename)
        if let decodedRelative = try container.decodeIfPresent(String.self, forKey: .relativePath) {
            relativePath = decodedRelative
        } else {
            relativePath = try container.decodeIfPresent(String.self, forKey: .path) ?? ""
        }
        preview = try container.decode(String.self, forKey: .preview)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        contentHash = try container.decodeIfPresent(String.self, forKey: .contentHash)
        fileSizeBytes = try container.decodeIfPresent(Int64.self, forKey: .fileSizeBytes)
        roomID = try container.decodeIfPresent(String.self, forKey: .roomID)
        healthStatus = try container.decodeIfPresent(ArtifactIndexHealthStatus.self, forKey: .healthStatus) ?? .valid
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(workflowID, forKey: .workflowID)
        try container.encode(title, forKey: .title)
        try container.encode(type, forKey: .type)
        try container.encode(filename, forKey: .filename)
        try container.encode(relativePath, forKey: .relativePath)
        try container.encode(preview, forKey: .preview)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(contentHash, forKey: .contentHash)
        try container.encodeIfPresent(fileSizeBytes, forKey: .fileSizeBytes)
        try container.encodeIfPresent(roomID, forKey: .roomID)
        try container.encode(healthStatus, forKey: .healthStatus)
    }

    func resolvedURL(in workspaceURL: URL) -> URL? {
        Self.fileURL(for: relativePath, workspaceURL: workspaceURL)
    }
}

struct ArtifactStoreHealthReport: Codable, Equatable, Sendable {
    let totalArtifacts: Int
    let validArtifacts: Int
    let missingFiles: Int
    let invalidPaths: Int
    let hashMismatches: Int
    let recentIndexEntries: Int
    let staleRecentEntries: Int
}

struct ArtifactCleanupCandidate: Codable, Equatable, Sendable {
    let artifactID: String
    let filename: String
    let reason: String
    let createdAt: Date
}

enum ActionLogCompactionPolicy {
    static let maxBytes = 1_000_000
    static let keepRecentLines = 2_000
}

// MARK: - ArtifactStore (actor — 동시 접근 직렬화)

actor ArtifactStore {
    static let shared = ArtifactStore()
    private init() {}

    private(set) var lastActionLogCompactedAt: Date?
    private(set) var actionLogCompactionCount: Int = 0

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
    var rotatedActionLogURL: URL { workspaceURL.appendingPathComponent("action_log.1.jsonl") }
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
        await compactActionLogIfNeeded()
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

    func registerArtifact(_ artifact: IndexedArtifact) async {
        var list = loadArtifacts()
        let normalized = normalizeArtifact(artifact)
        list.removeAll { $0.id == normalized.id }
        list.append(normalized)
        guard let data = try? JSONEncoder().encode(list) else { return }
        try? data.write(to: artifactIndexURL, options: .atomic)
        AppLog.info("[ArtifactStore] 등록: \(normalized.filename) (\(normalized.type.rawValue))")
    }

    func loadArtifacts() -> [IndexedArtifact] {
        guard let data = try? Data(contentsOf: artifactIndexURL),
              let list = try? JSONDecoder().decode([IndexedArtifact].self, from: data) else {
            return []
        }
        return list.map { normalizeArtifact($0) }
    }

    func artifacts(forWorkflowID id: String) -> [IndexedArtifact] {
        loadArtifacts().filter { $0.workflowID == id }
    }

    func healthReport(recentEntries: [RecentArtifactIndexEntry] = []) -> ArtifactStoreHealthReport {
        let artifacts = loadArtifacts()
        let artifactsByID = Dictionary(artifacts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var validArtifacts = 0
        var missingFiles = 0
        var invalidPaths = 0
        var hashMismatches = 0

        for artifact in artifacts {
            switch artifact.healthStatus {
            case .valid:
                validArtifacts += 1
            case .missingFile:
                missingFiles += 1
            case .invalidExternalPath, .invalidRelativePath:
                invalidPaths += 1
            case .hashMismatch:
                hashMismatches += 1
            case .metadataOnly:
                validArtifacts += 1
            }
        }

        let staleRecentEntries = recentEntries.filter { entry in
            guard let artifact = artifactsByID[entry.artifactID] else { return true }
            return artifact.healthStatus != .valid && artifact.healthStatus != .metadataOnly
        }.count
        return ArtifactStoreHealthReport(
            totalArtifacts: artifacts.count,
            validArtifacts: validArtifacts,
            missingFiles: missingFiles,
            invalidPaths: invalidPaths,
            hashMismatches: hashMismatches,
            recentIndexEntries: recentEntries.count,
            staleRecentEntries: staleRecentEntries
        )
    }

    func cleanupCandidates(
        recentEntries: [RecentArtifactIndexEntry] = [],
        now: Date = Date()
    ) -> [ArtifactCleanupCandidate] {
        let artifacts = loadArtifacts()
        let recentIDs = Set(recentEntries.map(\.artifactID))
        let calendar = Calendar(identifier: .gregorian)
        return artifacts.compactMap { artifact in
            let createdAt = ISO8601DateFormatter().date(from: artifact.createdAt) ?? now
            if calendar.dateComponents([.day], from: createdAt, to: now).day ?? 0 >= 30 {
                return ArtifactCleanupCandidate(artifactID: artifact.id, filename: artifact.filename, reason: "olderThan30Days", createdAt: createdAt)
            }

            switch artifact.healthStatus {
            case .missingFile:
                return ArtifactCleanupCandidate(artifactID: artifact.id, filename: artifact.filename, reason: "missingFile", createdAt: createdAt)
            case .invalidExternalPath:
                return ArtifactCleanupCandidate(artifactID: artifact.id, filename: artifact.filename, reason: "invalidExternalPath", createdAt: createdAt)
            case .invalidRelativePath:
                return ArtifactCleanupCandidate(artifactID: artifact.id, filename: artifact.filename, reason: "invalidRelativePath", createdAt: createdAt)
            case .hashMismatch:
                return ArtifactCleanupCandidate(artifactID: artifact.id, filename: artifact.filename, reason: "hashMismatch", createdAt: createdAt)
            case .metadataOnly:
                if !recentIDs.contains(artifact.id) {
                    return ArtifactCleanupCandidate(artifactID: artifact.id, filename: artifact.filename, reason: "recentIndexMissing", createdAt: createdAt)
                }
                return nil
            case .valid:
                if !recentIDs.contains(artifact.id) {
                    return ArtifactCleanupCandidate(artifactID: artifact.id, filename: artifact.filename, reason: "recentIndexMissing", createdAt: createdAt)
                }
                return nil
            }
        }
    }

    private func normalizeArtifact(_ artifact: IndexedArtifact) -> IndexedArtifact {
        let (relativePath, pathStatus) = Self.normalizeStoredPath(artifact.relativePath, workspaceURL: workspaceURL)
        let resolvedRelativePath = relativePath.isEmpty ? artifact.relativePath : relativePath
        guard let url = Self.fileURL(for: resolvedRelativePath, workspaceURL: workspaceURL) else {
            return artifact.with(relativePath: "", healthStatus: pathStatus == .valid ? .invalidRelativePath : pathStatus)
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return artifact.with(relativePath: resolvedRelativePath, healthStatus: .missingFile)
        }

        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes?[.size] as? NSNumber)?.int64Value
        let contentHash: String? = {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        }()

        if let expectedHash = artifact.contentHash, let contentHash, expectedHash != contentHash {
            return artifact.with(
                relativePath: resolvedRelativePath,
                healthStatus: .hashMismatch,
                fileSizeBytes: size,
                contentHash: expectedHash
            )
        }

        if artifact.contentHash == nil {
            return artifact.with(
                relativePath: resolvedRelativePath,
                healthStatus: .metadataOnly,
                fileSizeBytes: size,
                contentHash: contentHash
            )
        }

        return artifact.with(
            relativePath: resolvedRelativePath,
            healthStatus: pathStatus == .valid ? .valid : pathStatus,
            fileSizeBytes: size,
            contentHash: contentHash ?? artifact.contentHash
        )
    }

    private func compactActionLogIfNeeded() async {
        let maxBytes: Int64 = 1_000_000
        let keepRecentLines = 2_000
        let logURL = actionLogURL
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: logURL.path),
              let fileSize = attributes[.size] as? NSNumber,
              fileSize.int64Value > maxBytes,
              let data = try? Data(contentsOf: logURL),
              let text = String(data: data, encoding: .utf8) else {
            return
        }

        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        let trimmed = Array(lines.suffix(keepRecentLines)).joined(separator: "\n") + "\n"

        if FileManager.default.fileExists(atPath: rotatedActionLogURL.path) {
            try? FileManager.default.removeItem(at: rotatedActionLogURL)
        }
        try? FileManager.default.copyItem(at: logURL, to: rotatedActionLogURL)
        try? trimmed.write(to: logURL, atomically: true, encoding: .utf8)
        lastActionLogCompactedAt = Date()
        actionLogCompactionCount += 1
    }

    private static func fileURL(for relativePath: String, workspaceURL: URL) -> URL? {
        guard isSafeRelativePath(relativePath) else { return nil }
        return workspaceURL.appendingPathComponent(relativePath)
    }

    private static func isSafeRelativePath(_ path: String) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("/"), !trimmed.contains(":") else { return false }

        let parts = trimmed.split(separator: "/", omittingEmptySubsequences: true)
        guard !parts.isEmpty else { return false }

        for part in parts {
            let component = String(part)
            if component == "." || component == ".." || component.hasPrefix(".") {
                return false
            }
        }

        return true
    }

    private static func relativePath(for fileURL: URL, workspaceURL: URL) -> String? {
        let standardizedFileURL = fileURL.standardizedFileURL
        let standardizedWorkspaceURL = workspaceURL.standardizedFileURL
        let workspacePath = standardizedWorkspaceURL.path.hasSuffix("/")
            ? standardizedWorkspaceURL.path
            : standardizedWorkspaceURL.path + "/"

        guard standardizedFileURL.path == standardizedWorkspaceURL.path
            || standardizedFileURL.path.hasPrefix(workspacePath) else {
            return nil
        }

        let relative = String(standardizedFileURL.path.dropFirst(standardizedWorkspaceURL.path.count))
        let trimmed = relative.hasPrefix("/") ? String(relative.dropFirst()) : relative
        guard isSafeRelativePath(trimmed) else { return nil }
        return trimmed
    }

    private static func normalizeStoredPath(_ path: String, workspaceURL: URL) -> (relativePath: String, status: ArtifactIndexHealthStatus) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ("", .invalidRelativePath)
        }

        let url = URL(fileURLWithPath: trimmed)
        if trimmed.hasPrefix("/") {
            if let relativePath = relativePath(for: url, workspaceURL: workspaceURL) {
                return (relativePath, .valid)
            }
            return ("", .invalidExternalPath)
        }

        if isSafeRelativePath(trimmed) {
            return (trimmed, .valid)
        }

        return ("", .invalidRelativePath)
    }
}

private extension IndexedArtifact {
    static func fileURL(for relativePath: String, workspaceURL: URL) -> URL? {
        guard isSafeRelativePath(relativePath) else { return nil }
        return workspaceURL.appendingPathComponent(relativePath)
    }

    static func isSafeRelativePath(_ path: String) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("/"), !trimmed.contains(":") else { return false }

        let parts = trimmed.split(separator: "/", omittingEmptySubsequences: true)
        guard !parts.isEmpty else { return false }

        for part in parts {
            let component = String(part)
            if component == "." || component == ".." || component.hasPrefix(".") {
                return false
            }
        }

        return true
    }

    static func relativePath(for fileURL: URL, workspaceURL: URL) -> String? {
        let standardizedFileURL = fileURL.standardizedFileURL
        let standardizedWorkspaceURL = workspaceURL.standardizedFileURL
        let workspacePath = standardizedWorkspaceURL.path.hasSuffix("/")
            ? standardizedWorkspaceURL.path
            : standardizedWorkspaceURL.path + "/"

        guard standardizedFileURL.path == standardizedWorkspaceURL.path
            || standardizedFileURL.path.hasPrefix(workspacePath) else {
            return nil
        }

        let relative = String(standardizedFileURL.path.dropFirst(standardizedWorkspaceURL.path.count))
        let trimmed = relative.hasPrefix("/") ? String(relative.dropFirst()) : relative
        guard isSafeRelativePath(trimmed) else { return nil }
        return trimmed
    }

    static func normalizeStoredPath(_ path: String, workspaceURL: URL) -> (relativePath: String, status: ArtifactIndexHealthStatus) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ("", .invalidRelativePath)
        }

        let url = URL(fileURLWithPath: trimmed)
        if trimmed.hasPrefix("/") {
            if let relativePath = relativePath(for: url, workspaceURL: workspaceURL) {
                return (relativePath, .valid)
            }
            return ("", .invalidExternalPath)
        }

        if isSafeRelativePath(trimmed) {
            return (trimmed, .valid)
        }

        return ("", .invalidRelativePath)
    }

    func with(
        relativePath: String? = nil,
        healthStatus: ArtifactIndexHealthStatus? = nil,
        fileSizeBytes: Int64? = nil,
        contentHash: String? = nil
    ) -> IndexedArtifact {
        IndexedArtifact(
            id: id,
            workflowID: workflowID,
            title: title,
            type: type,
            filename: filename,
            relativePath: relativePath ?? self.relativePath,
            preview: preview,
            createdAt: createdAt,
            updatedAt: updatedAt,
            contentHash: contentHash ?? self.contentHash,
            fileSizeBytes: fileSizeBytes ?? self.fileSizeBytes,
            roomID: roomID,
            healthStatus: healthStatus ?? self.healthStatus
        )
    }
}
