import SwiftUI

// MARK: - ArtifactCardView

struct ArtifactCardView: View {
    let artifact: IndexedArtifact

    @State private var copied = false

    /// cloud artifact이면 URL(string:), local이면 URL(fileURLWithPath:).
    /// path가 비어 있거나 변환 실패 시 nil → 버튼 disabled.
    private var resolvedURL: URL? {
        guard !artifact.path.isEmpty else { return nil }
        if artifact.type == .cloud {
            return URL(string: artifact.path)
        }
        return URL(fileURLWithPath: artifact.path)
    }

    private var fileExists: Bool {
        guard artifact.type != .cloud else { return resolvedURL != nil }
        return FileManager.default.fileExists(atPath: artifact.path)
    }

    private var canInteract: Bool {
        resolvedURL != nil && fileExists
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
        if !fileExists { return "exclamationmark.circle" }
        return "checkmark.circle.fill"
    }

    private var statusColor: Color {
        if artifact.type == .cloud { return .blue }
        if !fileExists { return .orange }
        return .green
    }

    private var statusText: String {
        if artifact.type == .cloud { return "클라우드 저장" }
        if !fileExists { return "읽기 실패" }
        return "저장됨 • 재사용 가능"
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
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
        AppLog.debug("Artifact revealed in Finder: \(artifact.filename)")
    }

    private func copyPath() {
        guard canInteract else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(artifact.path, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
        AppLog.debug("Path copied to pasteboard: \(artifact.path)")
    }
}
