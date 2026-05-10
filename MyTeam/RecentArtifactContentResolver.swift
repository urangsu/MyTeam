import Foundation

struct RecentArtifactContentResolution: Equatable {
    let artifactID: String
    let sourceName: String
    let sourceText: String
}

enum RecentArtifactContentResolver {
    static var isAvailable: Bool { true }

    static let supportedExtensions: [String] = ["md", "markdown", "txt"]

    @MainActor
    static func canResolveLatestMarkdownArtifact(
        roomID: UUID,
        manager: AgentWindowManager
    ) -> Bool {
        resolveLatestMarkdownArtifact(roomID: roomID, manager: manager) != nil
    }

    @MainActor
    static func countReusableArtifacts(
        roomID: UUID,
        manager: AgentWindowManager
    ) -> Int {
        let recent = manager.recentArtifacts
        guard !recent.isEmpty else { return 0 }
        let workspaceURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("MyTeam/Workspace")
            .standardizedFileURL
        guard let workspaceURL else { return 0 }

        return recent.filter { artifact in
            let url = URL(fileURLWithPath: artifact.path)
            let standardized = url.standardizedFileURL.path
            let workspacePath = workspaceURL.path.hasSuffix("/") ? workspaceURL.path : workspaceURL.path + "/"
            guard standardized == workspaceURL.path || standardized.hasPrefix(workspacePath) else {
                return false
            }
            return supportedExtensions.contains(url.pathExtension.lowercased())
        }.count
    }

    @MainActor
    static func resolveLatestMarkdownArtifact(
        roomID: UUID,
        manager: AgentWindowManager
    ) -> RecentArtifactContentResolution? {
        guard let artifact = latestReusableArtifact(roomID: roomID, manager: manager) else {
            return nil
        }

        let url = URL(fileURLWithPath: artifact.path)
        guard isInsideWorkspace(url), isMarkdownLike(url) else {
            return nil
        }

        guard let text = readText(from: url) else { return nil }
        let limited = String(text.prefix(20_000)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limited.isEmpty else { return nil }

        let sourceName = artifact.filename.isEmpty ? artifact.title : artifact.filename
        return RecentArtifactContentResolution(
            artifactID: artifact.id,
            sourceName: sourceName.isEmpty ? "recent artifact" : sourceName,
            sourceText: limited
        )
    }

    @MainActor
    private static func latestReusableArtifact(
        roomID: UUID,
        manager: AgentWindowManager
    ) -> IndexedArtifact? {
        let recent = manager.recentArtifacts
        guard !recent.isEmpty else { return nil }

        let roomContext = manager.roomGoalContext(for: roomID)
        if let contextIDs = roomContext?.recentArtifactIDs, !contextIDs.isEmpty {
            let idSet = Set(contextIDs.map(\.uuidString))
            let matched = recent.filter { idSet.contains($0.id) }
            if let match = matched.first(where: { isMarkdownLike(URL(fileURLWithPath: $0.path)) && isInsideWorkspace(URL(fileURLWithPath: $0.path)) }) {
                return match
            }
        }

        return recent.first(where: {
            isMarkdownLike(URL(fileURLWithPath: $0.path)) && isInsideWorkspace(URL(fileURLWithPath: $0.path))
        })
    }

    private static func isMarkdownLike(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["md", "markdown", "txt"].contains(ext)
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

    private static func readText(from url: URL) -> String? {
        if let data = try? Data(contentsOf: url),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let text = try? String(contentsOf: url, encoding: .utf16) {
            return text
        }
        return nil
    }
}
