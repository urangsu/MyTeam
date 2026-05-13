import Foundation

struct WorkspaceRelativePath: Codable, Equatable, Hashable, Sendable {
    let value: String
}

enum WorkspacePathPolicy {
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
}
