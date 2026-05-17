import SwiftUI

// MARK: - ArtifactCardView

struct ArtifactCardView: View {
    let artifact: IndexedArtifact
    var compactMode: Bool = false

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
        if compactMode {
            compactView
        } else {
            standardView
        }
    }

    @ViewBuilder
    private var standardView: some View {
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

            // ── Friendly Recovery (초보자 안내 + 복구 버튼) ──
            if let recovery = friendlyRecovery {
                VStack(alignment: .leading, spacing: 6) {
                    Text(recovery.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        ForEach(recovery.actions, id: \.title) { action in
                            Button(action.title) { action.handler() }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.06))
                )
            }

            // Preview (optional)
            if !artifact.preview.isEmpty && canInteract {
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

    @ViewBuilder
    private var compactView: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(typeEmoji)
                .font(.body)

            VStack(alignment: .leading, spacing: 1) {
                Text(artifact.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(artifact.filename)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Compact status
            HStack(spacing: 4) {
                Image(systemName: statusIcon)
                    .font(.caption2)
                    .foregroundColor(statusColor)
                Text(statusText)
                    .font(.caption2)
                    .foregroundColor(statusColor)
            }

            // Minimal actions
            Button("열기") { openArtifact() }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(!canInteract)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
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
            return "파일 정보만 저장됨"
        case .missingFile:
            return "파일을 찾을 수 없습니다"
        case .invalidExternalPath, .invalidRelativePath:
            return "파일을 열 수 없음"
        case .hashMismatch:
            return "파일 상태가 바뀌었습니다"
        }
    }

    // MARK: - Friendly Recovery

    private struct RecoveryAction {
        let title: String
        let handler: () -> Void
    }

    private struct RecoveryInfo {
        let message: String
        let actions: [RecoveryAction]
    }

    private var friendlyRecovery: RecoveryInfo? {
        switch artifact.healthStatus {
        case .valid, .metadataOnly:
            return nil  // 정상 상태 — 복구 안내 불필요
        case .missingFile:
            return RecoveryInfo(
                message: "파일을 찾을 수 없어요. 다시 선택하면 이어서 정리할 수 있습니다.",
                actions: [
                    RecoveryAction(title: "새 문서로 시작") {
                        // 현재는 워크룸 기본 프롬프트로 안내
                        NotificationCenter.default.post(
                            name: Notification.Name("myteam.beginnerNewDocument"), object: nil)
                    }
                ]
            )
        case .hashMismatch:
            return RecoveryInfo(
                message: "파일 내용이 바뀐 것 같아요. 최신 파일로 다시 정리할 수 있어요.",
                actions: [
                    RecoveryAction(title: "새 문서로 시작") {
                        NotificationCenter.default.post(
                            name: Notification.Name("myteam.beginnerNewDocument"), object: nil)
                    }
                ]
            )
        case .invalidExternalPath, .invalidRelativePath:
            return RecoveryInfo(
                message: "파일을 열 수 없어요. 파일을 다시 선택해주세요.",
                actions: [
                    RecoveryAction(title: "새 문서로 시작") {
                        NotificationCenter.default.post(
                            name: Notification.Name("myteam.beginnerNewDocument"), object: nil)
                    }
                ]
            )
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
