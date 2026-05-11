import CryptoKit
import Foundation

struct RecentArtifactContentResolution: Equatable {
    let artifactID: String
    let sourceName: String
    let sourceText: String
    let binding: RecentArtifactSourceBinding
}

enum RecentArtifactContentResolver {
    static let isAvailable: Bool = true
    static let supportedExtensions: [String] = ["md", "markdown", "txt"]
    static let maxReusableArtifactBytes: Int64 = 2 * 1024 * 1024
    private static let maxReusableCharacterCount = 20_000

    @MainActor
    static func canResolveLatestMarkdownArtifact(
        roomID: UUID,
        manager: AgentWindowManager
    ) -> Bool {
        latestReusableArtifact(roomID: roomID, manager: manager, allowGlobalFallback: false) != nil
    }

    @MainActor
    static func countReusableArtifacts(
        roomID: UUID,
        manager: AgentWindowManager
    ) -> Int {
        reusableArtifactCandidates(roomID: roomID, manager: manager, allowGlobalFallback: false).count
    }

    @MainActor
    static func resolveLatestMarkdownArtifact(
        roomID: UUID,
        manager: AgentWindowManager,
        allowGlobalFallback: Bool = false
    ) async -> RecentArtifactContentResolution? {
        guard let artifact = latestReusableArtifact(
            roomID: roomID,
            manager: manager,
            allowGlobalFallback: allowGlobalFallback
        ) else {
            return nil
        }

        guard let resolution = await resolveArtifact(
            artifact,
            roomID: roomID
        ) else {
            return nil
        }

        return resolution
    }

    @MainActor
    static func currentBinding(
        roomID: UUID,
        manager: AgentWindowManager
    ) async -> RecentArtifactSourceBinding? {
        guard let artifact = latestReusableArtifact(roomID: roomID, manager: manager, allowGlobalFallback: false) else {
            return nil
        }
        return await resolveArtifact(artifact, roomID: roomID)?.binding
    }

    @MainActor
    private static func latestReusableArtifact(
        roomID: UUID,
        manager: AgentWindowManager,
        allowGlobalFallback: Bool
    ) -> IndexedArtifact? {
        let candidates = reusableArtifactCandidates(roomID: roomID, manager: manager, allowGlobalFallback: allowGlobalFallback)
        return candidates.first
    }

    @MainActor
    private static func reusableArtifactCandidates(
        roomID: UUID,
        manager: AgentWindowManager,
        allowGlobalFallback: Bool
    ) -> [IndexedArtifact] {
        let recent = manager.recentArtifacts
        guard !recent.isEmpty else { return [] }

        let roomContext = manager.roomGoalContext(for: roomID)
        let scopedArtifacts: [IndexedArtifact]

        if let contextIDs = roomContext?.recentArtifactIDs, !contextIDs.isEmpty {
            let idSet = Set(contextIDs.map(\.uuidString))
            scopedArtifacts = recent.filter { idSet.contains($0.id) }
        } else if allowGlobalFallback {
            scopedArtifacts = recent
        } else {
            return []
        }

        return scopedArtifacts.filter { artifact in
            let url = URL(fileURLWithPath: artifact.path)
            return isInsideWorkspace(url) && isMarkdownLike(url)
        }
    }

    private static func isMarkdownLike(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    private static func isInsideWorkspace(_ url: URL) -> Bool {
        let workspaceURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("MyTeam/Workspace")
            .standardizedFileURL

        guard let workspaceURL else { return false }
        let standardized = url.standardizedFileURL.path
        let workspacePath = workspaceURL.path.hasSuffix("/") ? workspaceURL.path : workspaceURL.path + "/"
        return standardized == workspaceURL.path || standardized.hasPrefix(workspacePath)
    }

    private static func resolveArtifact(
        _ artifact: IndexedArtifact,
        roomID: UUID
    ) async -> RecentArtifactContentResolution? {
        let url = URL(fileURLWithPath: artifact.path)
        guard isInsideWorkspace(url), isMarkdownLike(url) else { return nil }

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let sizeNumber = attributes[.size] as? NSNumber else {
            return nil
        }

        let fileSize = sizeNumber.int64Value
        guard fileSize <= maxReusableArtifactBytes else {
            return nil
        }

        guard let readResult = readPrefix(from: url) else { return nil }
        let sourceText = String(readResult.text.prefix(maxReusableCharacterCount)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceText.isEmpty else { return nil }

        let binding = RecentArtifactSourceBinding(
            roomID: roomID,
            artifactID: artifact.id,
            filename: artifact.filename,
            contentHash: readResult.contentHash,
            fileSizeBytes: fileSize,
            modifiedAt: readResult.modifiedAt,
            createdAt: parsedDate(artifact.createdAt) ?? readResult.modifiedAt
        )

        let sourceName = artifact.filename.isEmpty ? artifact.title : artifact.filename
        return RecentArtifactContentResolution(
            artifactID: artifact.id,
            sourceName: sourceName.isEmpty ? "recent artifact" : sourceName,
            sourceText: sourceText,
            binding: binding
        )
    }

    private static func readPrefix(from url: URL) -> (text: String, contentHash: String, modifiedAt: Date)? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let data: Data
        do {
            data = try handle.read(upToCount: Int(maxReusableArtifactBytes)) ?? Data()
        } catch {
            return nil
        }

        guard !data.isEmpty else { return nil }

        let text: String?
        if let utf8 = String(data: data, encoding: .utf8) {
            text = utf8
        } else if let utf16 = String(data: data, encoding: .utf16) {
            text = utf16
        } else {
            text = nil
        }

        guard let text else { return nil }

        let hash = SHA256.hash(data: data)
        let contentHash = hash.compactMap { String(format: "%02x", $0) }.joined()
        let modifiedAtAttributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let modifiedAt = modifiedAtAttributes?[.modificationDate] as? Date ?? Date()
        return (text: text, contentHash: contentHash, modifiedAt: modifiedAt)
    }

    private static func parsedDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: value)
    }
}
