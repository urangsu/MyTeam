import SwiftUI

// MARK: - ArtifactCardView

struct ArtifactCardView: View {
    let artifact: IndexedArtifact

    @State private var copied = false

    /// cloud artifact이면 URL(string:), local이면 workspace-relative path를 절대 경로로 resolve.
    private var resolvedURL: URL? {
        guard !artifact.relativePath.isEmpty else { return nil }
        if artifact.type == .cloud {
            return URL(string: artifact.relativePath)
        }
        return Self.fileURL(for: artifact.relativePath, workspaceURL: ToolExecutionContext.workspaceURL)
    }

    private var fileExists: Bool {
        guard artifact.type != .cloud else { return resolvedURL != nil }
        guard let url = resolvedURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    private var canInteract: Bool {
        guard artifact.type != .cloud else { return resolvedURL != nil }
        return fileExists && (artifact.healthStatus == .valid || artifact.healthStatus == .metadataOnly)
    }

    private var typeLabel: String {
        switch artifact.type {
        case .report:       return "보고서"
        case .presentation: return "프레젠테이션"
        case .spreadsheet:  return "스프레드시트"
        case .text:         return "문서"
        case .cloud:        return "클라우드"
        case .other:        return "기타"
        }
    }

    private var storageLabel: String {
        artifact.type == .cloud ? "Cloud" : "Workspace"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Title + Type + Date
            HStack(spacing: 6) {
                Text(typeEmoji)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(artifact.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(typeLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // File info: filename + storage
            HStack(spacing: 8) {
                Text(artifact.filename)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(storageLabel)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.1)))
            }

            // Status indicator
            statusView

            // Preview (optional)
            if !artifact.preview.isEmpty {
                Text(artifact.preview)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Actions (max 4 buttons)
            HStack(spacing: 6) {
                // Primary: open
                Button("열기") { openArtifact() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!canInteract)

                // Secondary: Finder (local only)
                if artifact.type != .cloud {
                    Button("Finder") { revealInFinder() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!canInteract)
                }

                // Copy path
                Button(copied ? "✓" : "복사") { copyPath() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!canInteract)

                Spacer()
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2)))
    }

    // MARK: - Status View

    private var statusView: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.caption2)
                .foregroundColor(statusColor)
            Text(statusText)
                .font(.caption2)
                .foregroundColor(statusColor)
        }
    }

    private var statusIcon: String {
        if artifact.type == .cloud { return "cloud.fill" }
        switch artifact.healthStatus {
        case .valid:
            return "checkmark.circle.fill"
        case .metadataOnly:
            return "doc.text"
        case .missingFile:
            return "exclamationmark.circle"
        case .invalidExternalPath, .invalidRelativePath:
            return "slash.circle"
        case .hashMismatch:
            return "exclamationmark.triangle"
        }
    }

    private var statusColor: Color {
        if artifact.type == .cloud { return .blue }
        switch artifact.healthStatus {
        case .valid:
            return .green
        case .metadataOnly:
            return .secondary
        case .missingFile:
            return .orange
        case .invalidExternalPath, .invalidRelativePath:
            return .red
        case .hashMismatch:
            return .yellow
        }
    }

    private var statusText: String {
        if artifact.type == .cloud { return "클라우드 저장" }
        switch artifact.healthStatus {
        case .valid:
            return "저장됨 • 재사용 가능"
        case .metadataOnly:
            return "메타데이터만"
        case .missingFile:
            return "파일을 찾을 수 없습니다"
        case .invalidExternalPath, .invalidRelativePath:
            return "경로 오류"
        case .hashMismatch:
            return "파일 상태가 바뀌었습니다"
        }
    }

    // MARK: - Helpers

    private var typeEmoji: String {
        switch artifact.type {
        case .report:       return "📄"
        case .presentation: return "📊"
        case .spreadsheet:  return "📈"
        case .text:         return "📝"
        case .cloud:        return "☁️"
        case .other:        return "📁"
        }
    }

    private var formattedDate: String {
        let iso = ISO8601DateFormatter()
        guard let date = iso.date(from: artifact.createdAt) else { return artifact.createdAt }
        let fmt = DateFormatter()
        fmt.dateFormat = "MM/dd HH:mm"
        return fmt.string(from: date)
    }

    private func openArtifact() {
        guard let url = resolvedURL, canInteract else { return }
        NSWorkspace.shared.open(url)
    }

    private func revealInFinder() {
        guard canInteract, let url = resolvedURL else { return }
        Task { @MainActor in
            _ = await ToolExecutionLayer.executeWorkspaceAction(kind: .revealInFinder, path: url.path)
            AppLog.debug("Artifact revealed in Finder: \(artifact.filename)")
        }
    }

    private func copyPath() {
        guard canInteract else { return }
        Task { @MainActor in
            guard let url = resolvedURL else { return }
            let result = await ToolExecutionLayer.executeWorkspaceAction(kind: .copyPath, path: url.path)
            if result.status == .succeeded {
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                AppLog.debug("Path copied to pasteboard: \(url.path)")
            }
        }
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
}
